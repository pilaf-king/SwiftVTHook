//
//  SwiftMethodTableModel.h
//  SwiftDemo
//
//  Created by 邓竹立 on 2021/3/1.
//

#import <Foundation/Foundation.h>
#import "SwiftDefines.h"
NS_ASSUME_NONNULL_BEGIN


@interface SwiftOverrideMethodModel : NSObject

@property (copy,atomic) NSString *overrideClassName;

@property (assign,atomic) uintptr_t overrideClass;

@property (assign,atomic) uintptr_t overrideMethod;

@property (assign,atomic) uintptr_t method;

@end


@interface SwiftMethodTableModel : NSObject

@property (strong,atomic)NSArray *vTable;

@property (strong,atomic)NSArray *overrideTable;

@end

NS_ASSUME_NONNULL_END
