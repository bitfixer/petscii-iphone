//
//  ViewController.m
//  testcam
//
//  Created by Gubbish on 4/25/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>

@implementation ViewController
{
    AVCaptureVideoPreviewLayer *_previewLayer;
    AVCaptureSession *_captureSession;
    AVCaptureStillImageOutput *_stillImageOutput;
}

@synthesize imgPicker;
@synthesize theImage = _theImage;

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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

- (IBAction)grabImage
{
    [self presentModalViewController:self.imgPicker animated:YES];
    //[self performSelector:@selector(takePicture) withObject:nil afterDelay:2.0];
}

- (void)takePicture
{
    [self.imgPicker takePicture];
    //[self.imgPicker 
    [self dismissModalViewControllerAnimated:YES];
}
     
- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingImage:(UIImage *)image editingInfo:(NSDictionary *)editingInfo
{
    //grabbedImage.image = image;
    self.theImage = [image retain];
    //[[picker parentViewController] dismissModalViewControllerAnimated:YES];
    [self dismissModalViewControllerAnimated:YES];
    
    [self performSelector:@selector(processImage) withObject:nil afterDelay:2.0];
}



- (void)prepareGlyphSignatures
{
    NSString *glyphString;
    NSString *thisGlyph;
    
    for (int ch = 0; ch < 256; ch++)
    {
        
        if (ch < 128)
        {
            thisGlyph = [NSString stringWithFormat:@"%d",ch];
        }
        else 
        {
            thisGlyph = [NSString stringWithFormat:@"%d",ch-128];
        }
        
        //NSLog(@"%@",thisGlyph);
        glyphString = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:thisGlyph 
                                                                                         ofType:@"txt"]
                                                encoding:NSUTF8StringEncoding
                                                   error:nil];
        
        int index = 0;
        unsigned char bit;
        for (int y = 0; y < 8; y++)
        {
            for (int x = 0; x < 8; x++)
            {
                
                bit = [glyphString characterAtIndex:index];
                
                if (bit == '0')
                {
                    if (ch < 128)
                        dctInput[x][y] = 0;
                    else 
                        dctInput[x][y] = 255;
                }
                else 
                {
                    if (ch < 128)
                        dctInput[x][y] = 255;
                    else 
                        dctInput[x][y] = 0;
                }
                
                index++;
            }
        }
        
        [self dctWithInput:dctInput andOutput:dctSignatures[ch]];
    }
    
    //NSLog(@"test");
    
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


- (void)processImage
{
    //UIImage *capturedImage;
    //theImage = grabbedImage.image;
    
    // check size
    double width = self.theImage.size.width;
    double height = self.theImage.size.height;
    
    double destWidth = 320;
    double ratio = width / destWidth;
    
    
    NSLog(@"image size: %f %f",width, height);
    
    // render into smaller image view
    UIView *smallView;
    smallView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
    
    UIImageView *imView;
    imView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 320, height/ratio)];
    // add image to view
    imView.image = self.theImage;
    
    [smallView addSubview:imView];
    
    // render to new image
    UIGraphicsBeginImageContextWithOptions(smallView.bounds.size, smallView.opaque, 0.0);
    [smallView.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage *newImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    grabbedImage.image = newImg;
    self.theImage = newImg;
    
    int iWidth;
    iWidth = self.theImage.size.width;
    height = self.theImage.size.height;
    
    NSLog(@"image new size: %d %f",iWidth, height);
    CFDataRef pixelData = CGDataProviderCopyData(CGImageGetDataProvider(self.theImage.CGImage));
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
    
    double startTime = CACurrentMediaTime();
    [self outputToWav:imgIndices withLength:1000];
    double endTime = CACurrentMediaTime();
    NSLog(@"took %f seconds to convert image",endImConvert-startImConvert);
    NSLog(@"took %f seconds to do total dct",endDct-startDct);
    NSLog(@"took %f seconds to copy data",copytime);
    NSLog(@"took %f seconds to calc dct",dcttime);
    NSLog(@"took %f seconds to match",matchtime);
    NSLog(@"took %f seconds to build wav",endTime-startTime);
    //NSLog(@"mindc %f maxdc %f",minDc,maxDc);
    
    // play the wav file
    NSString *fullWavPath;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES); 
    NSString *documentsDirectory = [paths objectAtIndex:0];
    fullWavPath = [documentsDirectory stringByAppendingString:@"/temp.wav"];
    
    AVAudioPlayer* theAudio=[[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:fullWavPath] error:NULL];  
    theAudio.delegate = self;  
    [theAudio play];
    
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

- (void)writeWavHeader:(unsigned char *)header withNumSamples:(int)numSamples
{
    int ChunkSizeStart = 4;
    int FormatStart = 8;
    int Subchunk1IDStart = FormatStart + 4;
    int Subchunk1SizeStart = Subchunk1IDStart + 4;
    int AudioFormatStart = Subchunk1SizeStart + 4;
    int NumChannelsStart = AudioFormatStart + 2;
    int SampleRateStart = NumChannelsStart + 2;
    int ByteRateStart = SampleRateStart + 4;
    int BlockAlignStart = ByteRateStart + 4;
    int BitsPerSampleStart = BlockAlignStart + 2;
    int Subchunk2IDStart = BitsPerSampleStart + 2;
    int Subchunk2SizeStart = Subchunk2IDStart + 4;
    
    // write ChunkID
    header[0] = 'R';
    header[1] = 'I';
    header[2] = 'F';
    header[3] = 'F';
    
    // write Format
    header[FormatStart] = 'W';
    header[FormatStart+1] = 'A';
    header[FormatStart+2] = 'V';
    header[FormatStart+3] = 'E';
    
    // write subchunk1ID
    header[Subchunk1IDStart] = 'f';
    header[Subchunk1IDStart+1] = 'm';
    header[Subchunk1IDStart+2] = 't';
    header[Subchunk1IDStart+3] = ' ';
    
    // write Subchunk1Size
    header[Subchunk1SizeStart] = 16; // PCM
    header[Subchunk1SizeStart+1] = 0;
    header[Subchunk1SizeStart+2] = 0;
    header[Subchunk1SizeStart+3] = 0; // PCM
    
    // write AudioFormat
    header[AudioFormatStart] = 1;
    header[AudioFormatStart+1] = 0; // PCM
    
    // write NumChannels
    header[NumChannelsStart] = 1;
    header[NumChannelsStart+1] = 0;
    
    // write sampleRate
    header[SampleRateStart] = 0x44;
    header[SampleRateStart+1] = 0xAC;
    header[SampleRateStart+2] = 0;
    header[SampleRateStart+3] = 0; // 44100
    
    // byterate
    // SampleRate * NumChannels * BitsPerSample/8
    // ie 44100 * 1 * 1 = 44100
    
    header[ByteRateStart] = 0x44;
    header[ByteRateStart+1] = 0xAC;
    header[ByteRateStart+2] = 0;
    header[ByteRateStart+3] = 0;
    
    // blockalign
    // NumChannels * BitsPerSample/8
    // ie 1 * 1 = 1
    
    header[BlockAlignStart] = 1;
    header[BlockAlignStart+1] = 0;
    
    // bitspersample
    
    header[BitsPerSampleStart] = 8;
    header[BitsPerSampleStart+1] = 0;
    
    // subchunk2ID
    
    header[Subchunk2IDStart] = 'd';
    header[Subchunk2IDStart+1] = 'a';
    header[Subchunk2IDStart+2] = 't';
    header[Subchunk2IDStart+3] = 'a';
    
    // subchunk2size
    // numSamples * NumChannels * BitsPerSample/8
    // ie numSamples
    
    unsigned char byte;
    byte = (numSamples & 0xFF000000) >> 24;
    
    header[Subchunk2SizeStart+3] = byte;
    byte = (numSamples & 0x00FF0000) >> 16;
    header[Subchunk2SizeStart+2] = byte;
    
    byte = (numSamples & 0x0000FF00) >> 8;
    header[Subchunk2SizeStart+1] = byte;
    
    byte = (numSamples & 0x000000FF);
    header[Subchunk2SizeStart] = byte;
    
    
    // ChunkSize
    long ChunkSize = numSamples + 36;
    
    byte = (ChunkSize & 0xFF000000) >> 24;
    
    header[ChunkSizeStart+3] = byte;
    byte = (ChunkSize & 0x00FF0000) >> 16;
    header[ChunkSizeStart+2] = byte;
    
    byte = (ChunkSize & 0x0000FF00) >> 8;
    header[ChunkSizeStart+1] = byte;
    
    byte = (ChunkSize & 0x000000FF);
    header[ChunkSizeStart] = byte;
    
    
}

- (void)bitToWav:(int)bit withSamples:(long)numSamples intoBuffer:(unsigned char *)buffer
{
    double sampleRate = 44100.0;
    
    // calculate frequency
    double frequency, currValue;
    double volume = 255.0;
    int cycles;
    if (bit == 0)
    {
        cycles = 1;
    }
    else 
    {
        cycles = 2;
    }
    
    
    /*
    int phaseCycles = numSamples / (cycles*2);
    
    unsigned char val;
    int currCycle = 0;
    for (int i = 0; i < cycles; i++)
    {
        val = 0;
        for (int j = 0; j < phaseCycles; j++)
        {
            buffer[currCycle] = val;
            currCycle++;
        }
        
        val = 255;
        for (int j = 0; j < phaseCycles; j++)
        {
            buffer[currCycle] = val;
            currCycle++;
        }
    }
    */
     
    //frequency = 1.0 / ( ((double)numSamples / ((double)(cycles*2)) / 44100.0) );
    
    frequency = sampleRate / (numSamples / (double)cycles);
    
    //frequency = 500;
    
    
    double a, da;
    a = 0;
    da = 2.0 * M_PI * frequency / sampleRate;
    
    for (int s = 0; s < numSamples; s++)
    {
        currValue = (sin(a) + 1.0) * volume * 0.5;
        buffer[s] = round(currValue);
        a = a + da;
        
        if (a > 2.0 * M_PI)
        {
            a -= 2.0 * M_PI;
        }
        
    }
    
}

- (void)outputToWav:(unsigned char *)dataToEncode withLength:(int)dataLength
{
    
    /*
    // create some samples
    
    // duration in seconds
    double duration = 1.0;
    double frequency = 2400.0;
    double sampleRate = 44100.0;
    double volume = 255.0;
    double a, da;
    double currValue;
    int headerlength = 44;
    int samplesize = 1;
    
    a = 0;
    da = 2.0 * M_PI * frequency / sampleRate;
    
    unsigned char *data;
    int numsamples = sampleRate * duration;
    */
    
    int carrierBits = 2000;
    int carrierEndBits = 2000;
    int numBits = (dataLength * 10) + carrierBits + carrierEndBits;
    int samplesPerBit = 36;
    long numsamples = numBits * samplesPerBit;
    int samplesize = 1;
    unsigned char *data;
    int headerlength = 44;
    
    data = (unsigned char *)malloc(sizeof(unsigned char)*((numsamples*samplesize) + headerlength));

    int position;
    //int bit = 0;
    
    
    /*
    for (int i = 0; i < numBits; i++)
    {
        position = 44 + (i * samplesPerBit);
        [self bitToWav:bit withSamples:samplesPerBit intoBuffer:&data[position]];
        bit = rand() % 2;
    }
    */
    
    int bit;
    unsigned char thisByte;
    unsigned char bitmask;
    position = 44;
    
    // add the carrier at the start, these are '1' bits
    for (int c = 0; c < carrierBits; c++)
    {
        [self bitToWav:1 withSamples:samplesPerBit intoBuffer:&data[position]];
        position += samplesPerBit;
    }
    
    
    for (int b = 0; b < dataLength; b++)
    {
        // start bit
        [self bitToWav:0 withSamples:samplesPerBit intoBuffer:&data[position]];
        position += samplesPerBit;
        
        thisByte = dataToEncode[b];
        bitmask = 0x80;
        
        // data bits
        for (int theBit = 0; theBit < 8; theBit++)
        {
            bit = (thisByte & bitmask) >> 7-theBit;
            bitmask = bitmask >> 1;
            
            //position = 44 + (((b*10)+1+theBit) * samplesPerBit);
            [self bitToWav:bit withSamples:samplesPerBit intoBuffer:&data[position]];
            position += samplesPerBit;
        }
        
        // stop bit
        
        [self bitToWav:1 withSamples:samplesPerBit intoBuffer:&data[position]];
        position += samplesPerBit;
    }
    
    // add the carrier at the end, these are '1' bits
    for (int c = 0; c < carrierEndBits; c++)
    {
        [self bitToWav:1 withSamples:samplesPerBit intoBuffer:&data[position]];
        position += samplesPerBit;
    }
     
    [self writeWavHeader:(unsigned char *)data withNumSamples:numsamples];
    
    // now create wav file
    NSString *fullWavPath;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES); 
    NSString *documentsDirectory = [paths objectAtIndex:0];
    fullWavPath = [documentsDirectory stringByAppendingString:@"/temp.wav"];
    
    NSData *fileData;
    fileData = [[NSData alloc] initWithBytes:data length:numsamples+headerlength];
    
    [[NSFileManager defaultManager] createFileAtPath:fullWavPath contents:fileData attributes:nil];
    
    //NSLog(fullWavPath);
    
    // free the memory
    free(data);
    
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

    
    
    self.imgPicker = [[UIImagePickerController alloc] init];
    self.imgPicker.allowsEditing = NO;
    self.imgPicker.delegate = self;
    self.imgPicker.sourceType = UIImagePickerControllerSourceTypeCamera;
    //self.imgPicker.showsCameraControls = NO;
    
    [self prepareGlyphSignatures];
    
    _captureSession = [[AVCaptureSession alloc] init];
    [self addVideoInput];
    [self addVideoPreviewLayer];
    [self addStillImageOutput];
    
    CGRect layerRect = [[[self view] layer] bounds];
    [_previewLayer setBounds:layerRect];
    [_previewLayer setPosition:CGPointMake(CGRectGetMidX(layerRect),
                                          CGRectGetMidY(layerRect))];
    [[[self view] layer] addSublayer:_previewLayer];
    [_captureSession startRunning];
    
    _grabButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    _grabButton.frame = CGRectMake(0, 400, 320, 80);
    [_grabButton addTarget:self action:@selector(captureStillImage) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_grabButton];
    
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
    NSDictionary *outputSettings = [[NSDictionary alloc] initWithObjectsAndKeys:AVVideoCodecJPEG,AVVideoCodecKey,nil];
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
        /*
        CFDictionaryRef exifAttachments = CMGetAttachment(imageSampleBuffer, kCGImagePropertyExifDictionary, NULL);
        if (exifAttachments)
        {
            NSLog(@"attachements: %@", exifAttachments);
        }
        else
        {
            NSLog(@"no attachments");
        }
        */
        
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:imageSampleBuffer];
        UIImage *image = [[UIImage alloc] initWithData:imageData];
        //[self setStillImage:image];
        //[image release];
        self.theImage = image;
        [image release];
        [self processImage];
        //[[NSNotificationCenter defaultCenter] postNotificationName:kImageCapturedSuccessfully object:nil];
    }];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    if (interfaceOrientation == UIInterfaceOrientationPortrait)
    {
        return YES;
    }
    
    
    return NO;
}

@end
