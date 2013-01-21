//
//  ViewController.h
//  testcam
//
//  Created by Gubbish on 4/25/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>

@interface ViewController : UIViewController <UINavigationControllerDelegate, UIImagePickerControllerDelegate, AVAudioPlayerDelegate>
{
    IBOutlet UIImageView *grabbedImage;
    IBOutlet UIButton *grabButton;
    IBOutlet UIView *resultView;
    
    UIImage *theImage;
    UIImagePickerController *imgPicker;
    
    double **dctInput;
    double *dctOutput;
    double **dctSignatures;
    double **imagedat;
    double **alphalookup;
    double ****cosalphalookup;
    //double
}

- (IBAction)grabImage;

@property (nonatomic, retain) UIImagePickerController *imgPicker;

- (void)writeWavHeader:(unsigned char *)header withNumSamples:(long)numSamples;

@end
