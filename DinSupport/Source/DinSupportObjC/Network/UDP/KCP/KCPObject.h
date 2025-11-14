//
//  KCPObject.h
//  KCPKit
//
//  Created by eki on 2020/7/16.
//  Copyright © 2020 eric3u. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class KCPObject;

@protocol KCPObjectDelegate <NSObject>

- (void)kcp:(KCPObject *)kcp didReceivedData:(NSData *)data;
- (void)kcpDidReceivedResetRequest:(KCPObject *)kcp;

@end

typedef int(^KCPObjectOutputDataHandle)(NSData *data);

@interface KCPObject: NSObject

@property (nonatomic, weak) id<KCPObjectDelegate> delegate;
@property (nonatomic, strong) NSString *convString;

/// 检查data所属的kcp conv
+ (nonnull NSString*)convOf:(NSData *)data;
/// Create KCPObject with conv ID
/// @param convID data link id. Need the same conv ID, that can be received.
/// @param outputDataHandle data handle to send kcp data.
- (instancetype)initWithConvID:(UInt32)convID
                 outputDataHandle:(KCPObjectOutputDataHandle)outputDataHandle;
/// 开始监听数据
- (void)startReceiving;
/// 停止监听数据
- (void)stopReceiving;
/// 交给kcp处理的数据
/// @param data 需要交给kcp处理的数据
- (void)inputData:(NSData *)data;
/// 通过kcp发送数据
/// @param data 需要发送的数据
- (void)sendData:(NSData *)data;
/// 通知重置此KCP
- (void)sendReset;

@end

NS_ASSUME_NONNULL_END
