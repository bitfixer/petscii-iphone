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

@interface ViewController : UIViewController <UINavigationControllerDelegate,
UIImagePickerControllerDelegate, AVAudioPlayerDelegate, AVCaptureVideoDataOutputSampleBufferDelegate>
{
    UIImageView *_grabbedImage;
    UIButton *_grabButton;
    UIView *_resultView;
    
    UIImage *_theImage;
    UIImagePickerController *_imgPicker;
    
    double **dctWeights;
    double **dctInput;
    double *dctOutput;
    double **dctVert;
    double **dctSignatures;
    double **imagedat;
    double **alphalookup;
    double ****cosalphalookup;
    
    double *alphalookup1d;
    double **cosalphalookup1d;
    double ***pixBrightness;
    
    int _dctCoeffCheckLimit;
    //double
}

- (IBAction)grabImage;

@property (nonatomic, retain) UIImagePickerController *imgPicker;
@property (nonatomic, retain) UIImage *theImage;
@property (nonatomic, retain) NSArray *sortedGlyphSignatures;

- (void)writeWavHeader:(unsigned char *)header withNumSamples:(long)numSamples;

@end
