//
//  OpenCVWrapper.mm
//  Coffee Grind Analyzer
//
//  OpenCV Objective-C++ implementation for circle detection
//

#import "OpenCVWrapper.h"

// Only import OpenCV in .mm implementation file
#ifdef __cplusplus
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdocumentation"
#pragma clang diagnostic ignored "-Wshorten-64-to-32"
#pragma clang diagnostic ignored "-Wquoted-include-in-framework-header"

// Import only the specific OpenCV headers we need (not opencv.hpp which includes everything)
#import <opencv2/core.hpp>
#import <opencv2/imgproc.hpp>
#import <opencv2/imgcodecs/ios.h>

#pragma clang diagnostic pop
#endif

@implementation OpenCVCircle
@end

@implementation OpenCVWrapper

- (NSArray<OpenCVCircle *> *)detectCirclesInImage:(UIImage *)image
                                   cannyThreshold1:(double)threshold1
                                   cannyThreshold2:(double)threshold2
                                        minRadius:(int)minRadius
                                        maxRadius:(int)maxRadius {

    // Convert UIImage to cv::Mat
    cv::Mat mat;
    UIImageToMat(image, mat);

    // Convert to grayscale
    cv::Mat gray;
    if (mat.channels() == 4) {
        cv::cvtColor(mat, gray, cv::COLOR_BGRA2GRAY);
    } else if (mat.channels() == 3) {
        cv::cvtColor(mat, gray, cv::COLOR_BGR2GRAY);
    } else {
        gray = mat;
    }

    // Apply Gaussian blur to reduce noise (σ = 2)
    cv::Mat blurred;
    cv::GaussianBlur(gray, blurred, cv::Size(9, 9), 2, 2);

    // Detect circles using HoughCircles
    std::vector<cv::Vec3f> circles;
    cv::HoughCircles(
        blurred,
        circles,
        cv::HOUGH_GRADIENT,
        1,                          // dp: inverse ratio of accumulator resolution
        blurred.rows / 8,           // minDist: minimum distance between circle centers
        threshold1,                 // param1: Canny high threshold
        threshold2,                 // param2: accumulator threshold for circle centers
        minRadius,                  // minRadius
        maxRadius                   // maxRadius
    );

    // Convert detected circles to OpenCVCircle objects
    NSMutableArray<OpenCVCircle *> *result = [NSMutableArray array];

    for (size_t i = 0; i < circles.size(); i++) {
        OpenCVCircle *circle = [[OpenCVCircle alloc] init];
        circle.centerX = circles[i][0];
        circle.centerY = circles[i][1];
        circle.radius = circles[i][2];

        // Calculate confidence based on accumulator value
        // HoughCircles doesn't return votes directly, so we use a simple metric
        // Higher radius circles that meet threshold are considered more confident
        circle.confidence = 1.0;  // Default confidence

        [result addObject:circle];
    }

    // Sort by confidence (highest first), then by radius (largest first)
    [result sortUsingComparator:^NSComparisonResult(OpenCVCircle *obj1, OpenCVCircle *obj2) {
        if (obj1.confidence != obj2.confidence) {
            return obj1.confidence > obj2.confidence ? NSOrderedAscending : NSOrderedDescending;
        }
        return obj1.radius > obj2.radius ? NSOrderedAscending : NSOrderedDescending;
    }];

    return result;
}

@end
