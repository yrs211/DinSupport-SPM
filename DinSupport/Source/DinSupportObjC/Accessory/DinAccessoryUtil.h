//
//  DinAccessoryUtil.h
//  DinSupport
//
//  Created by Jin on 2021/4/24.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface DinAccessoryUtil : NSObject

+ (NSString *)str64ToHexStr:(NSString *)str64;
+ (NSString *)hexStrToStr64:(NSString *)hexstr;

+ (NSString *)encryptString:(NSString *)plainSourceStringToEncrypt;
+ (NSString *)decryptString:(NSString *)base64StringToDecrypt;

@end

NS_ASSUME_NONNULL_END
