//
//  OpenCVWrapper.h
//  Coffee Grind Analyzer
//
//  OpenCV Objective-C++ wrapper for Swift interoperability
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

// Prevent OpenCV headers from being imported in Swift context
#ifdef __cplusplus
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#endif

NS_ASSUME_NONNULL_BEGIN

// Detected circle result object
@interface OpenCVCircle : NSObject
@property (nonatomic, assign) CGFloat centerX;
@property (nonatomic, assign) CGFloat centerY;
@property (nonatomic, assign) CGFloat radius;
@property (nonatomic, assign) CGFloat confidence;
@end

// OpenCV wrapper for circle detection
@interface OpenCVWrapper : NSObject

/// Detect circles in image using Canny edge detection + Hough Circle Transform
/// @param image The UIImage to process
/// @param threshold1 Canny high threshold (default: 100)
/// @param threshold2 Hough accumulator threshold (default: 30)
/// @param minRadius Minimum circle radius in pixels
/// @param maxRadius Maximum circle radius in pixels
/// @return Array of detected circles sorted by confidence
- (NSArray<OpenCVCircle *> *)detectCirclesInImage:(UIImage *)image
                                   cannyThreshold1:(double)threshold1
                                   cannyThreshold2:(double)threshold2
                                        minRadius:(int)minRadius
                                        maxRadius:(int)maxRadius;

@end

NS_ASSUME_NONNULL_END

#ifdef __cplusplus
#pragma clang diagnostic pop
#endif
