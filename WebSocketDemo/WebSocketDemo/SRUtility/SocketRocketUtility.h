//
//  SocketRocketUtility.h
//  SUN
//
//  Created by 孙俊 on 17/2/16.
//  Copyright © 2017年 SUN. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <SocketRocket.h>


typedef enum : NSUInteger {
    disConnectByUser ,
    disConnectByServer,
} DisConnectType;


/**
 设置代理,用于接收websocket传来的消息或socket确认连接后,在外部进行处理相关事宜
 */
@protocol ZYWebSocketDelegate <NSObject>

- (void)getMessageFromSocket:(NSDictionary *)message;
- (void)socketDidOpen;

@end

@interface SocketRocketUtility : NSObject

@property (assign, nonatomic) id<ZYWebSocketDelegate>delegate;

/** 连接状态 */
@property (nonatomic,assign) SRReadyState socketReadyState;

+ (SocketRocketUtility *)instance;

/**
 开启连接
 */
-(void)SRWebSocketOpen;

/**
 关闭连接
 */
-(void)SRWebSocketClose;

/**
 发送数据

 @param data 发送的数据
 */
- (void)sendData:(id)data;


/**
 PingPong机制
 */
- (void)ping;

@end
