//
//  PSGrabController.m
//  testcam
//
//  Created by Gubbish on 1/21/13.
//
//

#import "PSGrabController.h"
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>

@interface PSGrabController ()

@end

@implementation PSGrabController
{
    UIImageView *_grabbedImage;
    UIButton *_grabButton;
    UIView *_resultView;
    
    UIImage *_theImage;
    //UIImagePickerController *_imgPicker;
    
    double **dctInput;
    double *dctOutput;
    double **dctSignatures;
    double **imagedat;
    double **alphalookup;
    double ****cosalphalookup;
    
    AVCaptureVideoPreviewLayer *_previewLayer;
    AVCaptureSession *_captureSession;
    AVCaptureStillImageOutput *_stillImageOutput;
    
    UIImage *_capturedImage;
}

@synthesize capturedImage = _capturedImage;

- (id) init
{
    self = [super init];
    if (self)
    {
    }
    return self;
}

- (void)dealloc
{
    [_captureSession release]; _captureSession = nil;
    [_previewLayer release]; _previewLayer = nil;
    [super dealloc];
}

- (double)alpha:(double)e
{
    if (e == 0)
    {
        return 1.0/sqrt(2.0);
    }
    else
    {
        return 1.0;
    }
}

- (void)viewDidLoad
{
    
    [super viewDidLoad];
	// Do any additional setup after loading the view, typically from a nib.
    
    imagedat = (double **)malloc(sizeof(double *) * 320.0);
    for (int i = 0; i < 320; i++)
    {
        imagedat[i] = (double *)malloc(sizeof(double) * 200.0);
    }
    
    dctSignatures = (double **)malloc(sizeof(double *) * 256);
    for (int i = 0; i < 256; i++)
    {
        dctSignatures[i] = (double *)malloc(sizeof(double) * 64);
    }
    
    dctInput = (double **)malloc(sizeof(double *) * 8);
    for (int i = 0; i < 8; i++)
    {
        dctInput[i] = (double *)malloc(sizeof(double) * 8);
    }
    
    dctOutput = (double *)malloc(sizeof(double) * 64);
    
    alphalookup = (double **)malloc(sizeof(double *) * 8);
    for (int i = 0; i < 8; i++)
    {
        alphalookup[i] = (double *)malloc(sizeof(double) * 8);
    }
    
    // populate alpha lookup table
    for(int i = 0; i < 8; i++)
    {
        for(int j = 0; j < 8; j++)
        {
            alphalookup[i][j] = [self alpha:(double)i] * [self alpha:(double)j];
        }
    }
    
    cosalphalookup = (double ****)malloc(sizeof(double ***) * 8);
    for (int i = 0; i < 8; i++)
    {
        cosalphalookup[i] = (double ***)malloc(sizeof(double **) * 8);
        for (int j = 0; j < 8; j++)
        {
            cosalphalookup[i][j] = (double **)malloc(sizeof(double *) * 8);
            for (int k = 0; k < 8; k++)
            {
                cosalphalookup[i][j][k] = (double *)malloc(sizeof(double) * 8);
            }
        }
        
    }
    
    for(int u = 0; u < 8; u++)
    {
        for(int v = 0; v < 8; v++)
        {
            for(int i = 0; i < 8; i++)
            {
                for(int j = 0; j < 8; j++)
                {
                    cosalphalookup[u][v][i][j] =  alphalookup[i][j]*
                    cos(((M_PI*u)/(2*8))*(2*i + 1))*
                    cos(((M_PI*v)/(2*8))*(2*j + 1));
                }
            }
        }
    }

    _captureSession = [[AVCaptureSession alloc] init];
    _captureSession.sessionPreset = AVCaptureSessionPreset640x480;
    [self addVideoInput];
    [self addVideoPreviewLayer];
    [self addStillImageOutput];
    
    
    CGRect layerRect = [[[self view] layer] bounds];
    [_previewLayer setBounds:layerRect];
    [_previewLayer setPosition:CGPointMake(CGRectGetMidX(layerRect),CGRectGetMidY(layerRect))];
    [[[self view] layer] addSublayer:_previewLayer];
    
    _grabButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    _grabButton.frame = CGRectMake(0, 400, 320, 80);
    [_grabButton addTarget:self action:@selector(captureStillImage) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_grabButton];
    
    [_captureSession startRunning];
    
    _grabbedImage = [[UIImageView alloc] init];
    _grabbedImage.frame = CGRectMake(0, 0, 320, 200);
    [self.view addSubview:_grabbedImage];
    
    _resultView = [[UIView alloc] init];
    _resultView.frame = CGRectMake(0, 200, 320, 200);
    _resultView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:_resultView];
}


- (void)addVideoInput {
	AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	if (videoDevice) {
		NSError *error;
		AVCaptureDeviceInput *videoIn = [AVCaptureDeviceInput deviceInputWithDevice:videoDevice error:&error];
		if (!error) {
			if ([_captureSession canAddInput:videoIn])
				[_captureSession addInput:videoIn];
			else
				NSLog(@"Couldn't add video input");
		}
		else
			NSLog(@"Couldn't create video input");
	}
	else
		NSLog(@"Couldn't create video capture device");
}

- (void)addVideoPreviewLayer {
	_previewLayer = [[[AVCaptureVideoPreviewLayer alloc] initWithSession:_captureSession] autorelease];
	[_previewLayer setVideoGravity:AVLayerVideoGravityResizeAspectFill];
    
}

- (void)addStillImageOutput
{
    _stillImageOutput = [[[AVCaptureStillImageOutput alloc] init] autorelease];
    NSDictionary *outputSettings = [[[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil] autorelease];
    [_stillImageOutput setOutputSettings:outputSettings];
    
    AVCaptureConnection *videoConnection = nil;
    for (AVCaptureConnection *connection in [_stillImageOutput connections]) {
        for (AVCaptureInputPort *port in [connection inputPorts]) {
            if ([[port mediaType] isEqual:AVMediaTypeVideo] ) {
                videoConnection = connection;
                break;
            }
        }
        if (videoConnection) {
            break;
        }
    }
    
    [_captureSession addOutput:_stillImageOutput];
}


- (void)captureStillImage
{
	AVCaptureConnection *videoConnection = nil;
	for (AVCaptureConnection *connection in [_stillImageOutput connections]) {
		for (AVCaptureInputPort *port in [connection inputPorts]) {
			if ([[port mediaType] isEqual:AVMediaTypeVideo]) {
				videoConnection = connection;
				break;
			}
		}
		if (videoConnection) {
            break;
        }
	}
    
	NSLog(@"about to request a capture from: %@", _stillImageOutput);
	[_stillImageOutput captureStillImageAsynchronouslyFromConnection:videoConnection
                                                   completionHandler:^(CMSampleBufferRef imageSampleBuffer, NSError *error)
     {
         NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
         UIImage *image = [[UIImage alloc] initWithData:imageData];
         self.capturedImage = image;
         [image release];
         //_grabbedImage.image = self.capturedImage;
         [self processImage];
         //[self performSelector:@selector(captureStillImage) withObject:nil afterDelay:0.0];
     }];
}


- (void)processImage
{
    // check size
    double width = self.capturedImage.size.width;
    double height = self.capturedImage.size.height;
    
    double destWidth = 320;
    double ratio = width / destWidth;
    
    NSLog(@"image size: %f %f",width, height);
    
    double startA = CACurrentMediaTime();
    // render into smaller image view
    UIView *smallView;
    smallView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
    
    UIImageView *imView;
    imView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 320, height/ratio)];
    // add image to view
    imView.image = self.capturedImage;
    [smallView addSubview:imView];
    
    // render to new image
    UIGraphicsBeginImageContextWithOptions(smallView.bounds.size, smallView.opaque, 0.0);
    [smallView.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage *newImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    double endA = CACurrentMediaTime();
    
    _grabbedImage.image = newImg;
    self.capturedImage = newImg;
    
    int iWidth;
    iWidth = self.capturedImage.size.width;
    height = self.capturedImage.size.height;
    
    NSLog(@"image new size: %d %f",iWidth, height);
    CFDataRef pixelData = CGDataProviderCopyData(CGImageGetDataProvider(self.capturedImage.CGImage));
    const UInt8* data = CFDataGetBytePtr(pixelData);
    
    double startImConvert = CACurrentMediaTime();
    
    int x,y,xx,yy;
    int matching;
    UIImageView *frag;
    UIImage *thisImg;
    NSString *imgFname;
    for (y = 0; y < 200; y++)
    {
        for (x = 0; x < 320; x++)
        {
            imagedat[x][y] = [self pixelBrightness:data:iWidth:x:y];
        }
    }
    
    double endImConvert = CACurrentMediaTime();
    
    NSLog(@"done conversion.");
    
    double startDct = CACurrentMediaTime();
    
    unsigned char *imgIndices;
    imgIndices = (unsigned char *)malloc(sizeof(unsigned char) * 1000);
    int currImgIndex = 0;
    
    double copytime = 0;
    double dcttime = 0;
    double matchtime = 0;
    // step through blocks
    for (y = 0; y < 200; y+= 8)
    {
        for (x = 0; x < 320; x+= 8)
        {
            double s = CACurrentMediaTime();
            // copy values into input buffer
            for (yy = 0; yy < 8; yy ++)
            {
                for (xx = 0; xx < 8; xx++)
                {
                    dctInput[xx][yy] = imagedat[x+xx][y+yy];
                }
            }
            double e = CACurrentMediaTime();
            copytime += e-s;
            
            s = CACurrentMediaTime();
            [self dctWithInput:dctInput andOutput:dctOutput];
            e = CACurrentMediaTime();
            dcttime += e-s;
            
            frag = [[UIImageView alloc] initWithFrame:CGRectMake(x, y, 8, 8)];
            
            s = CACurrentMediaTime();
            matching = [self getMatchingGlyph:dctOutput];
            e = CACurrentMediaTime();
            matchtime += e-s;
            
            
            if (matching < 128)
            {
                imgFname = [NSString stringWithFormat:@"%d.png",matching];
            }
            else
            {
                imgFname = [NSString stringWithFormat:@"%d_r.png",matching-128];
            }
            thisImg = [UIImage imageNamed:imgFname];
            frag.image = thisImg;
            
            [_resultView addSubview:frag];
            
            // add image index
            imgIndices[currImgIndex] = matching;
            currImgIndex++;
        }
    }
    
    double endDct = CACurrentMediaTime();
    
    NSLog(@"done!");
    
    // now create wav file
    /*
     double startTime = CACurrentMediaTime();
     [self outputToWav:imgIndices withLength:1000];
     double endTime = CACurrentMediaTime();
     */
    NSLog(@"took %f seconds to convert image",endImConvert-startImConvert);
    NSLog(@"took %f seconds to do total dct",endDct-startDct);
    NSLog(@"took %f seconds to copy data",copytime);
    NSLog(@"took %f seconds to calc dct",dcttime);
    NSLog(@"took %f seconds to match",matchtime);
    NSLog(@"took %f seconds to convert image",endA-startA);
    //NSLog(@"took %f seconds to build wav",endTime-startTime);
    //NSLog(@"mindc %f maxdc %f",minDc,maxDc);
    
    /*
     // play the wav file
     NSString *fullWavPath;
     NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
     NSString *documentsDirectory = [paths objectAtIndex:0];
     fullWavPath = [documentsDirectory stringByAppendingString:@"/temp.wav"];
     
     AVAudioPlayer* theAudio=[[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:fullWavPath] error:NULL];
     theAudio.delegate = self;
     [theAudio play];
     */
    
}


-(double) pixelBrightness:(const UInt8 *)imageData: (int)width: (int) x:(int) y
{
    //NSLog(@"x %d y %d",x,y);
    
    int scale = 2;
    int pixelinfo = (((width*scale) * (y*scale)) + (x*scale)) * 4;
    
    UInt8 red = imageData[pixelinfo];
    UInt8 green = imageData[pixelinfo+1];
    UInt8 blue = imageData[pixelinfo+2];
    
    //NSLog(@"r %d g %d b %d",red,green,blue);
    
    double dist;
    dist = sqrt((double)red*(double)red + (double)green*(double)green + (double)blue*(double)blue);
    dist  = dist / sqrt(3.0);
    
    //NSLog(@"dist is %f",dist);
    
    return dist;
}

- (void)dctWithInput:(double **)input andOutput:(double *)output
{
    int u,v,i,j;
    double result;
    for(u = 0; u < 8; u++) //
    {
        for(v = 0; v < 8; v++)
        {
            result = 0; // reset summed results to 0
            for(i = 0; i < 8; i++)
            {
                for(j = 0; j < 8; j++)
                {
                    result = result + (cosalphalookup[u][v][i][j] * input[i][j]);
                }
            }
            output[u+v*8] = result; //store the results
        }
    }
}

- (double)getDctDiffBetween:(double *)inputA and:(double *)inputB
{
    
    double dcDiff = inputA[0]-inputB[0];
    if (dcDiff > 3000 || dcDiff < -3000)
    {
        return DBL_MAX;
    }
    
    double score, diff;
    score = 0;
    for (int i = 0; i < 64; i++)
    {
        diff = (inputA[i]-inputB[i]);
        diff = diff*diff;
        
        score += diff;
    }
    
    return score;
}

- (int)getMatchingGlyph:(double *)dctSearch
{
    double lowest = DBL_MAX;
    double curr_score;
    int matchIndex;
    for (int d = 0; d < 256; d++)
    {
        //NSLog(@"checking index %d",d);
        curr_score = [self getDctDiffBetween:dctSearch and:dctSignatures[d]];
        
        if (curr_score < lowest)
        {
            matchIndex = d;
            lowest = curr_score;
        }
    }
    
    //NSLog(@"match %d",matchIndex);
    
    //double dcDiff = dctSearch[0] - dctSignatures[matchIndex][0];
    //NSLog(@"match dc diff %f",dcDiff);
    
    return matchIndex;
}


@end
