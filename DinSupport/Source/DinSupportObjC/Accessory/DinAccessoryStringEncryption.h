//
//  DinAccessoryStringEncryption.h
//  DinSupport
//
//  Created by Jin on 2021/4/24.
//

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonDigest.h>
#import <CommonCrypto/CommonCryptor.h>

NS_ASSUME_NONNULL_BEGIN

#define kChosenCipherBlockSize    kCCBlockSizeAES128
#define kChosenCipherKeySize    kCCKeySizeAES128
#define kChosenDigestLength        CC_SHA1_DIGEST_LENGTH

@interface DinAccessoryStringEncryption : NSObject

+ (NSString *)encryptString:(NSString *)plainSourceStringToEncrypt;
+ (NSString *)decryptString:(NSString *)base64StringToDecrypt;
+ (NSData *)encrypt:(NSData *)plainText;
+ (NSData *)decrypt:(NSData *)plainText;
+ (NSData *)doCipher:(NSData *)plainText context:(CCOperation)encryptOrDecrypt;

@end

NS_ASSUME_NONNULL_END
