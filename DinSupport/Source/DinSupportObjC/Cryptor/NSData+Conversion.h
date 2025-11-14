#import <Foundation/Foundation.h>

@interface NSData (NSData_Conversion)

#pragma mark - String Conversion
- (NSData * _Nullable)cryptoWithKey:(NSString * _Nonnull)key isEncrypt:(BOOL)isEncrypt;

// AES 加密
- (NSData * _Nullable)aes_cbc_encryptWith:(NSData * _Nonnull)key iv:(NSData * _Nonnull)iv;
- (NSData * _Nullable)aes_cbc_decryptWith:(NSData * _Nonnull)key iv:(NSData * _Nonnull)iv;
@end
