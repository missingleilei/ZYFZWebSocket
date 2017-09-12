//
//  ViewController.m
//  NXWebSocketDemo
//
//  Created by 张洋 on 2017/9/11.
//  Copyright © 2017年 com.iyuba. All rights reserved.
//

#import "ViewController.h"
#import <AFNetworking.h>
#import <SocketRocket.h>
#import "SocketRocketUtility.h"


#define KToolBar 44
#define KNavagationBar 64
#define kScreenW [UIScreen mainScreen].bounds.size.width
#define kScreenH [UIScreen mainScreen].bounds.size.height
#define RGBColor(r,g,b) [UIColor colorWithRed:(r)/255.0 green:(g)/255.0 blue:(b)/255.0 alpha:1.0]

@interface ViewController ()<UITextFieldDelegate,ZYWebSocketDelegate>{
    
    UIButton     *socketConnectBtn;
    UIButton     *socketDisConnectBtn;
    UIButton     *socketSendMessageBtn;
    UIButton     *socketPingBtn;
    
    UITextField  *sendMessageTF;
    
}

@end

@implementation ViewController

/*
 源码解析 :http://www.jianshu.com/p/cdb7a886789a
 WebSocket协议是基于TCP的一种新的网络协议。它实现了浏览器与服务器全双工(full-duplex)通信——可以通俗的解释为服务器主动发送信息给客户端。
 
 这个框架给我们封装的webscoket在调用它的sendPing senddata方法之前，一定要判断当前scoket是否连接，如果不是连接状态，程序则会crash。
 
 退出账号，APP退出到后台等操作需要主动断开Socket链接
 */


/**
 记得退出页面关闭socket
 */

-(void)viewWillDisappear:(BOOL)animated{
    [super viewWillDisappear:YES];
    [self socketDisConnectClick];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //[self registNotification];
    
    [self CreateUI];
}

//- (void)registNotification{
//    
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SRWebSocketDidOpen) name:@"kWebSocketDidOpenNote" object:nil];
//    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SRWebSocketDidReceiveMsg:) name:@"kWebSocketdidReceiveMessageNote" object:nil];
//}
//- (void)dealloc{
//    
//    [[NSNotificationCenter defaultCenter] removeObserver:self];
//}
#pragma mark 创建UI
- (void)CreateUI{
    
    socketPingBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    socketPingBtn.frame = CGRectMake(50,100,kScreenW-100, 50);
    socketPingBtn.backgroundColor = RGBColor(51, 152, 204);
    [socketPingBtn setTitle:@"PingWBSocket" forState:UIControlStateNormal];
    socketPingBtn.layer.cornerRadius = 10;
    socketPingBtn.layer.masksToBounds = YES;
    [socketPingBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    [socketPingBtn addTarget:self action:@selector(socketPingClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:socketPingBtn];
    
    
    socketConnectBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    socketConnectBtn.frame = CGRectMake(50,170,kScreenW-100, 50);
    socketConnectBtn.backgroundColor = RGBColor(51, 152, 204);
    [socketConnectBtn setTitle:@"链接WBSocket" forState:UIControlStateNormal];
    socketConnectBtn.layer.cornerRadius = 10;
    socketConnectBtn.layer.masksToBounds = YES;
    [socketConnectBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    [socketConnectBtn addTarget:self action:@selector(socketConnectClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:socketConnectBtn];
    
    
    socketDisConnectBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    socketDisConnectBtn.frame = CGRectMake(50,240,kScreenW-100, 50);
    socketDisConnectBtn.backgroundColor = RGBColor(51, 152, 204);
    [socketDisConnectBtn setTitle:@"关闭WBSocket" forState:UIControlStateNormal];
    socketDisConnectBtn.layer.cornerRadius = 10;
    socketDisConnectBtn.layer.masksToBounds = YES;
    [socketDisConnectBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    [socketDisConnectBtn addTarget:self action:@selector(socketDisConnectClick) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:socketDisConnectBtn];
    
    sendMessageTF = [[UITextField alloc] initWithFrame:CGRectMake(50, 320, kScreenW-100, 50)];
    sendMessageTF.borderStyle = UITextBorderStyleNone;
    sendMessageTF.placeholder = @"请输入发送信息";
    sendMessageTF.font = [UIFont fontWithName:@"Arial" size:15.0f];;
    sendMessageTF.textColor = [UIColor blackColor];
    sendMessageTF.backgroundColor = [UIColor whiteColor];
    sendMessageTF.clearsOnBeginEditing = NO;
    sendMessageTF.textAlignment = NSTextAlignmentLeft;
    sendMessageTF.keyboardType = UIKeyboardTypeDefault;
    sendMessageTF.secureTextEntry = NO;
    sendMessageTF.delegate = self;
    [self.view addSubview:sendMessageTF];
    
    UIView  *sendMessageLine = [[UIView alloc] initWithFrame:CGRectMake(50, sendMessageTF.frame.origin.y + 40, kScreenW-2*50,1)];
    sendMessageLine.backgroundColor = [UIColor lightGrayColor];
    [self.view addSubview:sendMessageLine];
    
    socketSendMessageBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    socketSendMessageBtn.frame = CGRectMake(50,400,kScreenW-100, 50);
    socketSendMessageBtn.backgroundColor = RGBColor(51, 152, 204);
    [socketSendMessageBtn setTitle:@"发送消息" forState:UIControlStateNormal];
    socketSendMessageBtn.layer.cornerRadius = 10;
    socketSendMessageBtn.layer.masksToBounds = YES;
    [socketSendMessageBtn setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    
    [socketSendMessageBtn addTarget:self action:@selector(socketSendMessage) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:socketSendMessageBtn];
    
    
    UITapGestureRecognizer *ViewTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(viewTapped:)];
    ViewTap.cancelsTouchesInView = NO;
    [self.view addGestureRecognizer:ViewTap];
}
#pragma mark UITextFieldDelegate
- (BOOL)textFieldShouldReturn:(UITextField *)textField{
    
    [textField resignFirstResponder];
    [self keyBoardClose];
    return YES;
}
#pragma mark -UITextFieldDelegate 调整键盘遮挡问题
- (void)textFieldDidBeginEditing:(UITextField *)textField{
    
    
    CGRect frame = textField.frame;
    CGFloat heights = self.view.frame.size.height;
    // 当前点击textfield的坐标的Y值 + 当前点击textFiled的高度 - （屏幕高度- 键盘高度 - 键盘上tabbar高度）
    // 在这一部 就是了一个 当前textfile的的最大Y值 和 键盘的最全高度的差值，用来计算整个view的偏移量
    int offset = frame.origin.y + 42- ( heights - 216.0-35.0);//键盘高度216
    NSTimeInterval animationDuration = 0.30f;
    [UIView beginAnimations:@"ResizeForKeyBoard" context:nil];
    [UIView setAnimationDuration:animationDuration];
    
    float width = self.view.frame.size.width;
    float height = self.view.frame.size.height;
    if(offset > 0){
        
        CGRect rect = CGRectMake(0.0f, -offset,width,height);
        self.view.frame = rect;
    }
    [UIView commitAnimations];
}

#pragma mark - 手势收键盘
-(void)viewTapped:(UITapGestureRecognizer*)tap1{
    [self keyBoardClose];
}

#pragma mark - 收键盘
- (void)keyBoardClose{
    
    [self.view endEditing:YES];
    NSTimeInterval animationDuration = 0.30f;
    [UIView beginAnimations:@"ResizeForKeyboard" context:nil];
    [UIView setAnimationDuration:animationDuration];
    CGRect rect = CGRectMake(0.0f, 0.0f, self.view.frame.size.width, self.view.frame.size.height);
    self.view.frame = rect;
    [UIView commitAnimations];
    [self.view endEditing:YES];
}
#pragma mark ======== PingWBSoket ==========
- (void)socketPingClick{
    [[SocketRocketUtility instance] ping];
   
}

#pragma mark ======== 链接WBSoket ==========
- (void)socketConnectClick{
    [[SocketRocketUtility instance] SRWebSocketOpen];
     [SocketRocketUtility instance].delegate = self;
}

#pragma mark ======== 关闭WBSoket ==========
- (void)socketDisConnectClick{
    [[SocketRocketUtility instance] SRWebSocketClose];
}
#pragma mark ======== 发送消息 生成字典转为NSData后转为json字符串==========
- (void)socketSendMessage{
    
    if (sendMessageTF.text.length == 0) {
        return;
    }
    
    NSError *error;
    NSMutableDictionary *messageDic = [[NSMutableDictionary alloc] initWithObjectsAndKeys:sendMessageTF.text,@"message", nil];
    
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:messageDic options:NSJSONWritingPrettyPrinted error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];

    [[SocketRocketUtility instance] sendData:jsonString];
    
}
#pragma mark 一一WebSocket协议方法一一一一一一一一一一一一一一一一一一一一一一一一一一一一
- (void)getMessageFromSocket:(NSDictionary *)message {
    //接收到消息后做相关处理 刷新tableview
    NSLog(@"message = %@",message);
}

- (void)socketDidOpen{
    NSLog(@"开启成功");
    //    NSError *error;
    //    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{@"type":@"login"
    //                                                                 } options:NSJSONWritingPrettyPrinted error:&error];
    //    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    //    [[SocketRocketUtility instance] sendData:jsonString];
}
//#pragma mark ========  在成功后需要做的操作 ==========
//- (void)SRWebSocketDidOpen {
//    NSLog(@"开启成功");
////    NSError *error;
////    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:@{@"type":@"login"
////                                                                 } options:NSJSONWritingPrettyPrinted error:&error];
////    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
////    [[SocketRocketUtility instance] sendData:jsonString];
//}
//
//#pragma mark ========  收到服务端发送过来的消息 ==========
//- (void)SRWebSocketDidReceiveMsg:(NSNotification *)note {
//    
//    NSString * message = note.object;
//    NSLog(@"%@",message);
//}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    
}


@end
