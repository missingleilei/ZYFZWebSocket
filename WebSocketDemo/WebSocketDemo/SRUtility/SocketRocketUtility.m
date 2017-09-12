//
//  SocketRocketUtility.m
//  SUN
//
//  Created by 孙俊 on 17/2/16.
//  Copyright © 2017年 SUN. All rights reserved.
//

#import "SocketRocketUtility.h"

#define dispatch_main_async_safe(block)\
if ([NSThread isMainThread]) {\
block();\
} else {\
dispatch_async(dispatch_get_main_queue(), block);\
}
#define WeakSelf(ws) __weak __typeof(&*self)weakSelf = self

@interface SocketRocketUtility()<SRWebSocketDelegate>{
    
    NSTimer         *heartBeat;
    NSTimeInterval  reConnectTime;
}

@property (nonatomic,strong) SRWebSocket *socket;

@end

@implementation SocketRocketUtility

/**
 心跳机制就不难了，开个定时器，问下后台要每隔多少秒发送一次心跳请求就好了。然后注意，断网了或者socket断开的时候把心跳关一下，省资源，不然都断网了，还在循环发心跳，浪费CPU和电量。
 */

#pragma mark ========  Socket初始化   ==========
+(SocketRocketUtility *)instance{
    
    //关键字static修饰的局部变量的作用，让局部变量永远只初始化一次，一份内存，生命周期已经跟全局变量类似了，只是作用域不变。
    static SocketRocketUtility *Instance = nil;
    static dispatch_once_t predicate;
    dispatch_once(&predicate, ^{
        Instance = [[SocketRocketUtility alloc] init];
    });
    return Instance;
}

#pragma mark ======== SRWebSocket建立连接  ==========
-(void)SRWebSocketOpen{
    
    if (self.socket) {//如果是同一个url return
        return;
    }
    
    self.socket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"请求的地址"]]];
    NSLog(@"请求的WebSocket地址：%@",self.socket.url.absoluteString);

    /*
     //设置代理线程queue
     NSOperationQueue *queue = [[NSOperationQueue alloc]init];
     queue.maxConcurrentOperationCount = 1;
     [webSocket setDelegateOperationQueue:queue];
     */
    self.socket.delegate = self; // 实现这个 SRWebSocketDelegate
    [self.socket open];// open 直接连接Socket
}

#pragma mark ======== SRWebSocket关闭连接==========
-(void)SRWebSocketClose{
    /*
     if (webSocket) {
     [webSocket closeWithCode:disConnectByUser reason:@"用户主动断开"];
     webSocket = nil;
     }
     */
    if (self.socket){
        [self.socket close];
        self.socket = nil;
        //断开连接时销毁心跳
        [self destoryHeartBeat];
    }
}

#pragma mark ======== SRWebSocket代理  连接成功会调用这个代理方法 ==========
- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    
    NSLog(@"连接成功，可以立刻登录你公司后台的服务器了，还有开启心跳，每次正常连接的时候清零重连时间");
    reConnectTime = 0;
    
    //开启心跳
    [self initHeartBeat];
    
    if (webSocket == self.socket) {
        NSLog(@"************************** socket 连接成功************************** ");
        
        //[[NSNotificationCenter defaultCenter] postNotificationName:@"kWebSocketDidOpenNote" object:nil];
        [self.delegate socketDidOpen];
    }
}

#pragma mark ======== SRWebSocket代理  连接失败会调用这个方法 ==========
- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {

    NSLog(@"连接失败，这里可以实现掉线自动重连，要注意以下几点");
    NSLog(@"1.判断当前网络环境，如果断网了就不要连了，等待网络到来，在发起重连");
    NSLog(@"2.判断调用层是否需要连接，例如用户都没在聊天界面，连接上去浪费流量");
    NSLog(@"3.连接次数限制，如果连接失败了，重试10次左右就可以了，不然就死循环了。或者每隔1，2，4，8，10，10秒重连...f(x) = f(x-1) * 2, (x=5)");
    
    if (webSocket == self.socket) {
        NSLog(@"************************** socket 连接失败************************** ");
        _socket = nil;
        //连接失败就重连
        [self reConnect];
    }
}

#pragma mark ======== SRWebSocket代理  连接关闭调用这个方法，注意连接关闭不是连接断开，关闭是 [socket close] 客户端主动关闭，断开可能是断网了，被动断开的。 ==========
- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    
    /*
    //如果是被用户自己中断的那么直接断开连接，否则开始重连
    if (code == disConnectByUser) {
        NSLog(@"被用户关闭连接，不重连");
        [self SRWebSocketClose];
    }else{
        NSLog(@"其他原因关闭连接，开始重连...");
        [self reConnect];
    }
     */
    
    
    NSLog(@"连接断开，清空socket对象，清空该清空的东西，还有关闭心跳！");
    
    if (webSocket == self.socket) {
        NSLog(@"************************** socket连接断开************************** ");
        NSLog(@"被关闭连接，code:%ld,reason:%@,wasClean:%d",(long)code,reason,wasClean);
        [self SRWebSocketClose];
    }

}

#pragma mark ======== SRWebSocket代理  收到服务器发来的数据会调用这个方法 ==========
- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    
    if (webSocket == self.socket) {
        NSLog(@"收到数据了，注意 message 是 id 类型的，学过C语言的都知道，id 是 (void *)void* 就厉害了，二进制数据都可以指着，不详细解释 void* 了");
        NSLog(@"************************** socket收到数据了************************** ");
        NSLog(@"我这后台约定的 message 是 json 格式数据收到数据，就按格式解析吧，然后把数据发给调用层");
        NSLog(@"message:%@",message);
        
        //[[NSNotificationCenter defaultCenter] postNotificationName:@"kWebSocketdidReceiveMessageNote" object:message];
       
        NSError *err;
        NSData *jsonData = [message dataUsingEncoding:NSUTF8StringEncoding];
        NSDictionary *dic = [NSJSONSerialization JSONObjectWithData:jsonData
                                                            options:NSJSONReadingMutableContainers
                                                              error:&err];
        [self.delegate getMessageFromSocket:dic];
        
    }
}

/*该函数是接收服务器发送的pong消息，其中最后一个是接受pong消息的，
 在这里就要提一下心跳包，一般情况下建立长连接都会建立一个心跳包，
 用于每隔一段时间通知一次服务端，客户端还是在线，这个心跳包其实就是一个ping消息，
 我的理解就是建立一个定时器，每隔十秒或者十五秒向服务端发送一个ping消息，这个消息可是是空的
 */

-(void)webSocket:(SRWebSocket *)webSocket didReceivePong:(NSData *)pongPayload{
    NSString *reply = [[NSString alloc] initWithData:pongPayload encoding:NSUTF8StringEncoding];
    NSLog(@"reply===%@",reply);
}


#pragma mark ======== SRWebSocket重连机制 ==========
- (void)reConnect{
    
    [self SRWebSocketClose];

    //超过一分钟就不再重连 所以只会重连5次 2^5 = 64
    if (reConnectTime > 64) {
        //您的网络状况不是很好，请检查网络后重试
        return;
    }
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(reConnectTime * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        self.socket = nil;
        [self SRWebSocketOpen];
        NSLog(@"重连");
    });
    
    //重连时间2的指数级增长
    if (reConnectTime == 0) {
        reConnectTime = 2;
    }else{
        reConnectTime *= 2;
    }
    
}
#pragma mark ======== 初始化心跳 ==========
- (void)initHeartBeat{
    
    dispatch_main_async_safe(^{
        [self destoryHeartBeat];
        
        //心跳设置为3分钟，NAT超时一般为5分钟
        heartBeat = [NSTimer timerWithTimeInterval:3*60 target:self selector:@selector(sentheart) userInfo:nil repeats:YES];
        //和服务端约定好发送什么作为心跳标识，尽可能的减小心跳包大小
        [[NSRunLoop currentRunLoop]addTimer:heartBeat forMode:NSRunLoopCommonModes];
    })
}

#pragma mark ======== 发送心跳 和后台可以约定发送什么内容 ==========
-(void)sentheart{
    
    [self sendData:@"heart"];
}

#pragma mark ======== 取消心跳 ==========
- (void)destoryHeartBeat{
    
    dispatch_main_async_safe(^{
        if (heartBeat) {
            if ([heartBeat respondsToSelector:@selector(isValid)]){
                if ([heartBeat isValid]){
                    [heartBeat invalidate];
                    heartBeat = nil;
                }
            }
        }
    })
}


#pragma mark ======== pingPong ==========
- (void)ping{
    if (self.socket.readyState == SR_OPEN) {
        [self.socket sendPing:nil];
    }
}

#pragma mark ======== 发送数据 ==========
- (void)sendData:(id)data {
    NSLog(@"socketSendData --------------- %@",data);
    
    WeakSelf(ws);
    dispatch_queue_t queue =  dispatch_queue_create("zy", NULL);
    
    dispatch_async(queue, ^{
        if (weakSelf.socket != nil) {
            // 只有 SR_OPEN 开启状态才能调 send 方法啊，不然要崩
            if (weakSelf.socket.readyState == SR_OPEN) {
                [weakSelf.socket send:data];    // 发送数据
                
            } else if (weakSelf.socket.readyState == SR_CONNECTING) {
                NSLog(@"正在连接中，重连后其他方法会去自动同步数据");
                // 每隔2秒检测一次 socket.readyState 状态，检测 10 次左右
                // 只要有一次状态是 SR_OPEN 的就调用 [ws.socket send:data] 发送数据
                // 如果 10 次都还是没连上的，那这个发送请求就丢失了，这种情况是服务器的问题了，小概率的
                // 代码有点长，我就写个逻辑在这里好了
                [self reConnect];
                
            } else if (weakSelf.socket.readyState == SR_CLOSING || weakSelf.socket.readyState == SR_CLOSED) {
                // websocket 断开了，调用 reConnect 方法重连
                
                NSLog(@"重连");
                
                [self reConnect];
            }
        } else {
            NSLog(@"没网络，发送失败，一旦断网 socket 会被我设置 nil 的");
            NSLog(@"其实最好是发送前判断一下网络状态比较好，我写的有点晦涩，socket==nil来表示断网");
        }
    });
}


-(SRReadyState)socketReadyState{
    return self.socket.readyState;
}


-(void)dealloc{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


@end
