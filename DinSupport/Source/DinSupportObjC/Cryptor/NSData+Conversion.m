#import "NSData+Conversion.h"
#import <CommonCrypto/CommonCryptor.h>

@implementation NSData (NSData_Conversion)

#pragma mark - String Conversion

- (NSData * _Nullable)cryptoWithKey:(NSString* _Nonnull)key isEncrypt:(BOOL)isEncrypt {
    if (key == nil || key.length < 1) {
        return nil;
    }
    
    NSUInteger length = [self length];
    
    Byte *bytes = (Byte*)malloc(length);
    memcpy(bytes, [self bytes], length);
    
    Byte *outBytes = malloc(length*sizeof(Byte));
    size_t out_size = 0;
    
    CCCryptorRef refer = NULL;
    
    CCCryptorCreate((isEncrypt ? kCCEncrypt : kCCDecrypt), kCCAlgorithmRC4, kCCOptionPKCS7Padding, (const void *)[key UTF8String] , [key length], NULL, &refer);
    if (! refer) {
        [NSException raise:@"error occured when encrypt" format:@""];
    }
    
    CCCryptorUpdate(refer,bytes, length, outBytes, length, &out_size);
    
    NSData *data = [NSData dataWithBytes:outBytes length:out_size];
    free(bytes);
    free(outBytes);
    CCCryptorRelease(refer);
    
    return data;
}

- (NSData *)aes_cbc_encryptWith:(NSData *)key iv:(NSData *)iv {
    NSData *retData = nil;
    NSUInteger dataLength = [self length];
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    bzero(buffer, bufferSize);
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCEncrypt, kCCAlgorithmAES128,
                                          kCCOptionPKCS7Padding,
                                          key.bytes, key.length,
                                          iv.bytes,
                                          self.bytes, self.length,
                                          buffer, bufferSize,
                                          &numBytesEncrypted);
    if (cryptStatus == kCCSuccess) {
        retData = [NSData dataWithBytes:buffer length:numBytesEncrypted];
    }
    free(buffer);
    return retData;
}

- (NSData *)aes_cbc_decryptWith:(NSData *)key iv:(NSData *)iv {
    NSData *retData = nil;
    NSUInteger dataLength = [self length];
    size_t bufferSize = dataLength + kCCBlockSizeAES128;
    void *buffer = malloc(bufferSize);
    bzero(buffer, bufferSize);
    size_t numBytesEncrypted = 0;
    CCCryptorStatus cryptStatus = CCCrypt(kCCDecrypt, kCCAlgorithmAES128,
                                          kCCOptionPKCS7Padding,
                                          key.bytes, key.length,
                                          iv.bytes,
                                          self.bytes, self.length,
                                          buffer, bufferSize,
                                          &numBytesEncrypted);
    if (cryptStatus == kCCSuccess) {
        retData = [NSData dataWithBytes:buffer length:numBytesEncrypted];
    }
    free(buffer);
    return retData;
}

@end
