//
//  DSKcpUpdateTimer.h
//  DinsaferIPC
//
//  Created by Jin on 2020/9/3.
//  Copyright © 2020 Dinsafer. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface DSKcpUpdateTimer : NSObject
- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithQueue:(dispatch_queue_t)queue exitcute:(dispatch_block_t _Nullable)handler;

- (void)resume;
@end

NS_ASSUME_NONNULL_END
