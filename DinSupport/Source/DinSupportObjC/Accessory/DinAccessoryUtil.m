//
//  DinAccessoryUtil.m
//  DinSupport
//
//  Created by Jin on 2021/4/24.
//

#import "DinAccessoryUtil.h"
#import "DinAccessoryStringEncryption.h"
#import "NSData+Base64.h"

@implementation DinAccessoryUtil

+ (NSString *)str64ToHexStr:(NSString *)str64 {

    NSArray *pattern = @[@"G", @"H", @"I", @"J", @"K", @"L", @"M", @"N",
                         @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V",
                         @"W", @"X", @"Y", @"Z", @"a", @"b", @"c", @"d",
                         @"e", @"f", @"g", @"h", @"i", @"j", @"k", @"l",
                         @"m", @"n", @"o", @"p", @"q", @"r", @"s", @"t",
                         @"u", @"v", @"w", @"x", @"y", @"z", @"0", @"1",
                         @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9",
                         @"A", @"B", @"C", @"D", @"E", @"F", @"$", @"@"];

    NSString *binStr = @"";
    int length = (int)str64.length;
    for (int i=0; i<length; i++) {
        int k = (int)[pattern indexOfObject:[str64 substringWithRange:NSMakeRange(i,1)]];
        binStr = [binStr stringByAppendingString:[self intTOBinary:k length:6]];
    }
    NSArray *spStr = [self splitString:binStr length:4];
    NSString *hexStr = @"";
    NSString *conHex = nil;
    BOOL firstChar = YES;
    for (NSString *bStr in spStr) {
        conHex = [self turn2To16:bStr];
        if ([conHex isEqualToString:@"0"] && [hexStr isEqualToString:@""] && [str64 length] != 10) {
            if (firstChar) {
                firstChar = NO;
            } else {
                hexStr = conHex;
            }
        } else {
            hexStr = [hexStr stringByAppendingString:[self turn2To16:bStr]];
        }
    }
    return hexStr;
}

+ (NSString *)hexStrToStr64:(NSString *)hexstr {
    NSArray *pattern = @[@"G", @"H", @"I", @"J", @"K", @"L", @"M", @"N",
                         @"O", @"P", @"Q", @"R", @"S", @"T", @"U", @"V",
                         @"W", @"X", @"Y", @"Z", @"a", @"b", @"c", @"d",
                         @"e", @"f", @"g", @"h", @"i", @"j", @"k", @"l",
                         @"m", @"n", @"o", @"p", @"q", @"r", @"s", @"t",
                         @"u", @"v", @"w", @"x", @"y", @"z", @"0", @"1",
                         @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9",
                         @"A", @"B", @"C", @"D", @"E", @"F", @"$", @"@"];
    NSString *binStr = @"";
    int length = (int)hexstr.length;
    for (int i=0; i<length; i++) {
        binStr = [binStr stringByAppendingString:[self turn16To2:[hexstr substringWithRange:NSMakeRange(i, 1)]]];
    }

    NSArray *spStr = [self splitString:binStr length:6];
    NSString *str64 = @"";
    for (NSString *bStr in spStr) {
        str64 = [str64 stringByAppendingString:pattern[[self turn2to10:bStr]]];
    }

    return str64;
}

+ (NSString *)intTOBinary:(int)i length:(int)length
{
    NSString *a = @"";
    while (i) {
        a = [[NSString stringWithFormat:@"%d",i%2] stringByAppendingString:a];
        if (i/2 < 1) {
            break;
        }
        i = i/2 ;
    }
    if (a.length <= length) {
        NSMutableString *b = [NSMutableString stringWithCapacity:length];
        int l = (int)(length - a.length);
        for (int i = 0; i < l; i++) {
            [b appendString:@"0"];
        }
        a = [b stringByAppendingString:a];
    }

    return a;

}

+ (NSArray *)splitString:(NSString *)binStr length:(int)len {
    //获取字符串长度
    int strlen = (int)binStr.length;
    //如果字符串长度小于指定的长度，则直接返回原字符串
    if (strlen <= len) {
        return @[binStr];
    }

    //取余数
    int headlen = strlen % len;
    NSString *cutStr = @"";
    NSMutableArray *buf = [NSMutableArray new];
    if (headlen > 0) {
        cutStr = [binStr substringToIndex:headlen];
        [buf addObject:cutStr];
        binStr = [binStr substringFromIndex:headlen];
    }

    strlen = strlen - headlen;
    while (strlen > 0) {
        cutStr = [binStr substringToIndex:len];
        [buf addObject:cutStr];
        strlen = strlen - len;
        binStr = [binStr substringFromIndex:len];
    }

    return buf;
}

+ (NSString *)turn2To16:(NSString *)binary {
    NSDictionary *hexDic = @{@"0000":@"0",
                             @"0001":@"1",
                             @"0010":@"2",
                             @"0011":@"3",
                             @"0100":@"4",
                             @"0101":@"5",
                             @"0110":@"6",
                             @"0111":@"7",
                             @"1000":@"8",
                             @"1001":@"9",
                             @"1010":@"A",
                             @"1011":@"B",
                             @"1100":@"C",
                             @"1101":@"D",
                             @"1110":@"E",
                             @"1111":@"F"};
    NSString *hex = hexDic[binary];
    if (hex == nil) {
        hex = @"0";
    }
    return hex;
}

+ (NSString *)turn16To2:(NSString *)hex {
    NSDictionary *binaryDic = @{@"0":@"0000",
                                @"1":@"0001",
                                @"2":@"0010",
                                @"3":@"0011",
                                @"4":@"0100",
                                @"5":@"0101",
                                @"6":@"0110",
                                @"7":@"0111",
                                @"8":@"1000",
                                @"9":@"1001",
                                @"A":@"1010",
                                @"B":@"1011",
                                @"C":@"1100",
                                @"D":@"1101",
                                @"E":@"1110",
                                @"F":@"1111"};
    NSString *binary = binaryDic[hex];
    return binary;
}

+ (int)turn2to10:(NSString *)str{
    int sum = 0;
    for (int i = 0; i < str.length; i++) {
        sum *= 2;
        char c = [str characterAtIndex:i];
        sum += c - '0';
    }
    return sum;
}

+ (NSString *)encryptString:(NSString *)plainSourceStringToEncrypt {
    return [DinAccessoryStringEncryption encryptString:plainSourceStringToEncrypt];
}

+ (NSString *)decryptString:(NSString *)base64StringToDecrypt {
    NSData *data = [DinAccessoryStringEncryption decrypt:[NSData dataWithBase64EncodedString:base64StringToDecrypt]];
    NSString *decryptString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    decryptString = [decryptString stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@"%c",0x03] withString:@""];
    decryptString = [decryptString stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    decryptString = [decryptString stringByReplacingOccurrencesOfString:@"\0" withString:@""];
    return decryptString;
}

@end
