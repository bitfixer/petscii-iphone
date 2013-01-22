//
//  PSGrabController.h
//  testcam
//
//  Created by Gubbish on 1/21/13.
//
//

#import <UIKit/UIKit.h>

@interface PSGrabController : UIViewController <UINavigationControllerDelegate,
                                                UIImagePickerControllerDelegate>

@property (nonatomic,retain) UIImage *capturedImage;

@end
