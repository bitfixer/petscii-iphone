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

#define GLYPH_DIM       8
#define GLYPH_DIM_SQ    64
#define GLYPH_OUT_DIM   8
#define DCT_WEIGHT_LIMIT 0.3
#define COLOR_LEVELS 128
#define COLOR_BIT_SHIFT 1

@implementation ViewController
{
    AVCaptureVideoPreviewLayer *_previewLayer;
    AVCaptureSession *_captureSession;
    AVCaptureStillImageOutput *_stillImageOutput;
    AVCaptureVideoDataOutput *_dataOutput;
    
    NSArray *_sortedGlyphSignatures;
    double *_sortedGlyphDCValues;
    int *_sortedGlyphIndices;
    unsigned char *_imgIndices;
    
    NSMutableArray *_fragmentImageViews;
    NSMutableArray *_glyphImages;
    BOOL _shouldCaptureNow;
    double _nextCaptureTime;
}

@synthesize imgPicker = _imgPicker;
@synthesize theImage = _theImage;
@synthesize sortedGlyphSignatures = _sortedGlyphSignatures;

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
        int stride = 8;
        int mult = stride/GLYPH_DIM;
        
        for (int y = 0; y < GLYPH_DIM; y++)
        {
            for (int x = 0; x < GLYPH_DIM; x++)
            {
                int yy = y*mult;
                int xx = x*mult;
                
                double sum = 0.0;
                for (int ya = yy; ya < yy+mult; ya++)
                {
                    for (int xa = xx; xa < xx+mult; xa++)
                    {
                        index = ya*stride + xa;
                        bit = [glyphString characterAtIndex:index];
                        
                        if (bit == '0')
                        {
                            if (ch < 128)
                                sum += 0;
                            else
                                sum += 255;
                        }
                        else
                        {
                            if (ch < 128)
                                sum += 255;
                            else
                                sum += 0;
                        }
                    }
                }
                sum /= (mult*mult);
                
                dctInput[x][y] = sum;
            }
        }
        
        
        /*
        for (int y = 0; y < GLYPH_DIM; y++)
        {
            for (int x = 0; x < GLYPH_DIM; x++)
            {
                double sum = 0.0;
                for (int )
                
                
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
        */
        
        [self dctWithInput:dctInput andOutput:dctSignatures[ch]];
    }
    
    // sort the glyph signatures
    NSMutableArray *signatures = [[[NSMutableArray alloc] init] autorelease];
    for (int i = 0; i < 256; i++)
    {
        NSArray *entry = [NSArray arrayWithObjects:[NSNumber numberWithDouble:dctSignatures[i][0]],
                                                                              [NSNumber numberWithInt:i],
                          nil];
        [signatures addObject:entry];
    }
    
    NSArray *sortedSignatures = [signatures sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2)
    {
        NSArray *firstArr = (NSArray *)obj1;
        NSArray *secondArr = (NSArray *)obj2;
        
        NSNumber *first = [firstArr objectAtIndex:0];
        NSNumber *second = [secondArr objectAtIndex:0];
        
        if ([first doubleValue] < [second doubleValue])
        {
            return (NSComparisonResult)NSOrderedAscending;
        }
        else if ([first doubleValue] > [second doubleValue])
        {
            return (NSComparisonResult)NSOrderedDescending;
        }
        return (NSComparisonResult)NSOrderedSame;
    }];
    
    int ii = 0;
    for (NSArray *arr in sortedSignatures)
    {
        NSNumber *dc = (NSNumber *)[arr objectAtIndex:0];
        NSNumber *ind = (NSNumber *)[arr objectAtIndex:1];
        double dcval = [dc doubleValue];
        int i = [ind intValue];
        
        NSLog(@"%f %d",dcval, i);
        
        _sortedGlyphDCValues[ii] = dcval;
        _sortedGlyphIndices[ii] = i;
        
        ii++;
    }
    
    self.sortedGlyphSignatures = sortedSignatures;
    
    NSLog(@"done sorting");
    
}

/*
- (void)dctWithInput:(double **)input andOutput:(double *)output
{
    double result;
    int outputindex = 0;
    for(int u = 0; u < 8; u++) //
    {
        outputindex = u;
        for(int v = 0; v < 8; v++)
        {
            result = 0; // reset summed results to 0
            
            for(int i = 0; i < 8; i++)
            {
                for(int j = 0; j < 8; j++)
                {
                    result = result + (cosalphalookup[u][v][i][j] * input[i][j]);
                }
            }
            output[outputindex] = result;
            outputindex += 8;
        }
    }
}
*/

- (void)dctWithInput:(double **)input andOutput:(double *)output
{
    double result;
    int outputindex = 0;
    
    // first do 1d DCT on columns
    for (int x = 0; x < GLYPH_DIM; x++)
    {
        for (int v = 0; v < GLYPH_DIM; v++)
        {
            result = 0;
            for (int j = 0; j < GLYPH_DIM; j++)
            {
                result += cosalphalookup1d[v][j] * input[x][j];
            }
            dctVert[x][v] = result;
        }
    }
    
    // now do 1d DCT on rows
    for (int y = 0; y < GLYPH_DIM; y++)
    {
        for (int u = 0; u < GLYPH_DIM; u++)
        {
            result = 0;
            if (dctWeights[u][y] > 0.3)
            {
                for (int i = 0; i < GLYPH_DIM; i++)
                {
                    result += cosalphalookup1d[u][i] * dctVert[i][y];
                }
                output[outputindex] = result*dctWeights[u][y];
                outputindex++;
            }
        }
    }
    
    /*
    for(int u = 0; u < GLYPH_DIM; u++) //
    {
        outputindex = u;
        for(int v = 0; v < GLYPH_DIM; v++)
        {
            result = 0; // reset summed results to 0
            if (dctWeights[u][v] > 0.3)
            {
                for(int i = 0; i < GLYPH_DIM; i++)
                {
                    for(int j = 0; j < GLYPH_DIM; j++)
                    {
                        result = result + (cosalphalookup[u][v][i][j] * input[i][j]);
                    }
                }
                output[outputindex] = result*dctWeights[u][v];
            }
            else
            {
                output[outputindex] = result;
            }
            
            outputindex += GLYPH_DIM;
        }
    }
    */
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
    /*
    double dcDiff = inputA[0]-inputB[0];
    if (dcDiff > 3000 || dcDiff < -3000)
    {
        return DBL_MAX;
    }
    */
     
    double score, diff;
    score = 0;
    
    for (int i = 0; i < _dctCoeffCheckLimit; i++)
    {
        diff = (inputA[i]-inputB[i]);
        diff = diff*diff;
        score += diff;
    }
     
    
    //int limit = GLYPH_DIM/2;
    /*
    int limit = GLYPH_DIM;
    int index = 0;
    for (int v = 0; v < limit; v++)
    {
        for (int u = 0; u < limit; u++)
        {
            if (dctWeights[u][v] > 0.3)
            {
                diff = (inputA[index] - inputB[index]);
                diff = diff*diff;
                score += diff;
            }
            
            //index += GLYPH_DIM;
            index++;
        }
    }
    */
     
    return score;
}

- (int)getMatchingGlyph:(double *)dctSearch
{
    double lowest = DBL_MAX;
    double curr_score;
    int matchIndex;
    
    double dc = dctSearch[0];
    double dc_low = dc - 3000.0;
    double dc_high = dc + 3000.0;
    double currdc;
    
    for (int d = 0; d < 256; d++)
    {
        currdc = _sortedGlyphDCValues[d];
        if (currdc > dc_low)
        {
            if (currdc > dc_high)
            {
                d = 256;
            }
            else
            {
                int dd = _sortedGlyphIndices[d];
                curr_score = [self getDctDiffBetween:dctSearch and:dctSignatures[dd]];
                if (curr_score < lowest)
                {
                    matchIndex = dd;
                    lowest = curr_score;
                }
            }
        }
    }
    
    return matchIndex;
}


- (void)processImage
{
    // check size
    double width = self.theImage.size.width;
    double height = self.theImage.size.height;
    
    double destWidth = 320;
    double ratio = width / destWidth;
    
    NSLog(@"image size: %f %f",width, height);
    
    double startA = CACurrentMediaTime();
    // render into smaller image view
    UIView *smallView;
    smallView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 200)];
    
    UIImageView *imView;
    imView = [[[UIImageView alloc] initWithFrame:CGRectMake(0, -60, 320, height/ratio)] autorelease];
    imView.transform = CGAffineTransformMakeScale(-1.0, 1.0);
    // add image to view
    imView.image = self.theImage;
    [smallView addSubview:imView];
    
    // render to new image
    UIGraphicsBeginImageContextWithOptions(smallView.bounds.size, smallView.opaque, 0.0);
    [smallView.layer renderInContext:UIGraphicsGetCurrentContext()];
    
    UIImage *newImg = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    //[smallView release];
    
    double endA = CACurrentMediaTime();
    
    _grabbedImage.image = newImg;
    self.theImage = newImg;
    //[newImg release];
    
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
    int mult = (8/GLYPH_DIM);
    int multsq = mult*mult;
    int yDim = 200 / mult;
    int xDim = 320 / mult;
    
    /*
    for (y = 0; y < yDim; y++)
    {
        for (x = 0; x < xDim; x++)
        {
            double sum = 0;
            for (yy = 0; yy < mult; yy++)
            {
                for (xx = 0; xx < mult; xx++)
                {
                    sum += [self pixelBrightness:data width:iWidth x:(x*mult)+xx y:(y*mult)+yy];
                }
            }
            //imagedat[x][y] = [self pixelBrightness:data width:iWidth x:x*mult y:y*mult];
            
            sum /= (double)multsq;
            imagedat[x][y] = sum;
        }
    }
    */
    for (y = 0; y < yDim; y++)
    {
        for (x = 0; x < xDim; x++)
        {
            imagedat[x][y] = [self pixelBrightness:data width:iWidth x:x y:y];
        }
    }
    
    
    CFRelease(pixelData);
    
    double endImConvert = CACurrentMediaTime();
    
    NSLog(@"done conversion.");
    
    double startDct = CACurrentMediaTime();
    
    //unsigned char *imgIndices;
    int currImgIndex = 0;
    
    double copytime = 0;
    double dcttime = 0;
    double matchtime = 0;
    
    // step through blocks
    for (y = 0; y < yDim; y+= GLYPH_DIM)
    {
        for (x = 0; x < xDim; x+= GLYPH_DIM)
        {
            double s = CACurrentMediaTime();
            // copy values into input buffer
            for (yy = 0; yy < GLYPH_DIM; yy ++)
            {
                for (xx = 0; xx < GLYPH_DIM; xx++)
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
            
            frag = [_fragmentImageViews objectAtIndex:currImgIndex];
            
            s = CACurrentMediaTime();
            matching = [self getMatchingGlyph:dctOutput];
            e = CACurrentMediaTime();
            matchtime += e-s;
            
            frag.image = [_glyphImages objectAtIndex:matching];
            
            // add image index
            _imgIndices[currImgIndex+10] = matching;
            currImgIndex++;
        }
    }
    
    double endDct = CACurrentMediaTime();
    
    NSLog(@"done!");
    
    // now create wav file
    double startTime = CACurrentMediaTime();
    
    /*
    for (int i = 0; i < 9; i++)
    {
        _imgIndices[i] = 0xff;
    }
    
    _imgIndices[9] = 0x00;
    
    [self outputToWav:_imgIndices withLength:1010];
    */
     
    double endTime = CACurrentMediaTime();
    NSLog(@"took %f seconds to convert image",endImConvert-startImConvert);
    NSLog(@"took %f seconds to do total dct",endDct-startDct);
    NSLog(@"took %f seconds to copy data",copytime);
    NSLog(@"took %f seconds to calc dct",dcttime);
    NSLog(@"took %f seconds to match",matchtime);
    NSLog(@"took %f seconds to convert image",endA-startA);
    NSLog(@"took %f seconds to build wav",endTime-startTime);
    //NSLog(@"mindc %f maxdc %f",minDc,maxDc);
    
    // play the wav file
    NSString *fullWavPath;
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentsDirectory = [paths objectAtIndex:0];
    fullWavPath = [documentsDirectory stringByAppendingString:@"/temp.wav"];
    
    /*
    AVAudioPlayer* theAudio=[[AVAudioPlayer alloc] initWithContentsOfURL:[NSURL fileURLWithPath:fullWavPath] error:NULL];  
    theAudio.delegate = self;  
    [theAudio play];
    */
}

-(double) pixelBrightness:(const UInt8 *)imageData width:(int)width x:(int)x y:(int)y
{
    int scale = 2;
    int pixelinfo = (((width*scale) * (y*scale)) + (x*scale)) * 4;
    
    UInt8 red = imageData[pixelinfo] >> COLOR_BIT_SHIFT;
    UInt8 green = imageData[pixelinfo+1] >> COLOR_BIT_SHIFT;
    UInt8 blue = imageData[pixelinfo+2] >> COLOR_BIT_SHIFT;
    
    /*
    double dist;
    dist = sqrt((double)red*(double)red + (double)green*(double)green + (double)blue*(double)blue);
    dist  = dist / sqrt(3.0);
    */
    
    return pixBrightness[red][green][blue];
    
    //return dist;
}

- (void)writeWavHeader:(unsigned char *)header withNumSamples:(long)numSamples
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
    /*
    header[SampleRateStart] = 0x44;
    header[SampleRateStart+1] = 0xAC;
    header[SampleRateStart+2] = 0;
    header[SampleRateStart+3] = 0; // 44100
    */
    
    header[SampleRateStart] = 0x80;
    header[SampleRateStart+1] = 0xBB;
    header[SampleRateStart+2] = 0;
    header[SampleRateStart+3] = 0; // 44100
    
    // byterate
    // SampleRate * NumChannels * BitsPerSample/8
    // ie 44100 * 1 * 1 = 44100
    
    /*
    header[ByteRateStart] = 0x44;
    header[ByteRateStart+1] = 0xAC;
    header[ByteRateStart+2] = 0;
    header[ByteRateStart+3] = 0;
    */
    
    header[ByteRateStart] = 0x80;
    header[ByteRateStart+1] = 0xBB;
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

- (void)bitToWav:(int)bit
     withSamples:(long)numSamples
      intoBuffer:(unsigned char *)buffer
{
    [self bitToWav:bit withSamples:numSamples intoBuffer:buffer squareWave:YES];
}


- (void)bitToWav:(int)bit
     withSamples:(long)numSamples
      intoBuffer:(unsigned char *)buffer
      squareWave:(BOOL)squareWave
{
    
    unsigned char val;
    if (bit == 0)
    {
        val = 255;
    }
    else if (bit == 1)
    {
        val = 0;
    }
    else
    {
        val = 128;
    }
    
    for (int i = 0; i < numSamples; i++)
    {
        buffer[i] = val;
    }
}


- (void)bitToWav2:(int)bit
     withSamples:(long)numSamples
      intoBuffer:(unsigned char *)buffer
      squareWave:(BOOL)squareWave
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
    
    if (squareWave)
    {
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
    }
    else
    {
        frequency = sampleRate / (numSamples / (double)cycles);
        
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
}

/*
- (void)outputToWav:(unsigned char *)dataToEncode withLength:(int)dataLength
{
    int carrierBits = 0;
    int carrierEndBits = 0;
    int numBits = (dataLength * 10) + carrierBits + carrierEndBits;
    int samplesPerBit = 5;
    long numsamples = numBits * samplesPerBit;
    int samplesize = 1;
    unsigned char *data;
    int headerlength = 44;
    
    data = (unsigned char *)malloc(sizeof(unsigned char)*((numsamples*samplesize) + headerlength));
    
    int position;
    
    int bit;
    unsigned char thisByte;
    unsigned char bitmask;
    position = 44;
    
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
}
*/

- (void)outputToWav:(unsigned char *)dataToEncode withLength:(int)dataLength
{
    int carrierBits = 100;
    int carrierEndBits = 100;
    int numBits = (dataLength * 10) + carrierBits + carrierEndBits;
    int samplesPerBit = 2;
    //long numsamples = numBits * samplesPerBit;
    long numsamples = (numBits / 2.0) * 5;
    
    int samplesize = 1;
    unsigned char *data;
    int headerlength = 44;
    int extraBitSize = 1;
    
    //data = (unsigned char *)malloc(sizeof(unsigned char)*((numsamples*samplesize) + headerlength));
    data = (unsigned char *)malloc(sizeof(unsigned char)*((numsamples*samplesize) + headerlength));

    int position;
    
    int bit;
    unsigned char thisByte;
    unsigned char bitmask;
    position = 44;
    
    int extraBit = 0;
    // add the carrier at the start, these are '1' bits
    for (int c = 0; c < carrierBits; c++)
    {
        [self bitToWav:1 withSamples:samplesPerBit intoBuffer:&data[position]];
        position += samplesPerBit;
    }
    
    for (int b = 0; b < dataLength; b++)
    {
        extraBit = 0;
        // start bit
        [self bitToWav:0 withSamples:(samplesPerBit+extraBit) intoBuffer:&data[position]];
        position += samplesPerBit+extraBit;
        
        thisByte = dataToEncode[b];
                
        bitmask = 0x01;
        
        // data bits
        for (int theBit = 0; theBit < 8; theBit++)
        {
            bit = (thisByte & bitmask) >> theBit;
            bitmask = bitmask << 1;
            
            if (extraBit == 0)
            {
                extraBit = extraBitSize;
            }
            else
            {
                extraBit = 0;
            }
            
            //position = 44 + (((b*10)+1+theBit) * samplesPerBit);
            [self bitToWav:bit withSamples:(samplesPerBit+extraBit) intoBuffer:&data[position]];
            position += samplesPerBit+extraBit;
        }
        
        // stop bit
        extraBit = extraBitSize;
        
        [self bitToWav:1 withSamples:(samplesPerBit+extraBit) intoBuffer:&data[position]];
        position += samplesPerBit+extraBit;
    }
    
    // add the carrier at the end, these are '1' bits
    for (int c = 0; c < carrierEndBits; c++)
    {
        [self bitToWav:1 withSamples:samplesPerBit intoBuffer:&data[position]];
        //[self bitToWav:0 withSamples:samplesPerBit intoBuffer:&data[position]];
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
    _nextCaptureTime = 0;
	// Do any additional setup after loading the view, typically from a nib.
    
    int xDim = 320 / (8/GLYPH_DIM);
    int yDim = 200 / (8/GLYPH_DIM);
    
    imagedat = (double **)malloc(sizeof(double *) * xDim);
    for (int i = 0; i < xDim; i++)
    {
        imagedat[i] = (double *)malloc(sizeof(double) * yDim);
    }
    
    dctSignatures = (double **)malloc(sizeof(double *) * 256);
    for (int i = 0; i < 256; i++)
    {
        dctSignatures[i] = (double *)malloc(sizeof(double) * GLYPH_DIM_SQ);
    }
    
    dctInput = (double **)malloc(sizeof(double *) * GLYPH_DIM);
    for (int i = 0; i < GLYPH_DIM; i++)
    {
        dctInput[i] = (double *)malloc(sizeof(double) * GLYPH_DIM);
    }
    
    dctVert = (double **)malloc(sizeof(double *) * GLYPH_DIM);
    for (int i = 0; i < GLYPH_DIM; i++)
    {
        dctVert[i] = (double *)malloc(sizeof(double) * GLYPH_DIM);
    }
    
    dctOutput = (double *)malloc(sizeof(double) * GLYPH_DIM_SQ);
    
    alphalookup1d = (double *)malloc(sizeof(double) * GLYPH_DIM);
    for (int i = 0; i < GLYPH_DIM; i++)
    {
        alphalookup1d[i] = [self alpha:(double)i];
    }
    
    cosalphalookup1d = (double **)malloc(sizeof(double *) * GLYPH_DIM);
    for (int i = 0; i < GLYPH_DIM; i++)
    {
        cosalphalookup1d[i] = (double *)malloc(sizeof(double) * GLYPH_DIM);
    }
    
    for (int u = 0; u < GLYPH_DIM; u++)
    {
        for (int i = 0; i < GLYPH_DIM; i++)
        {
            cosalphalookup1d[u][i] = alphalookup1d[i] *
            cos(((M_PI*u)/(2*GLYPH_DIM))*(2*i + 1));
            
            //cosalphalookup[u][v][i][j] =  alphalookup[i][j]*
            //cos(((M_PI*u)/(2*GLYPH_DIM))*(2*i + 1))*
            //cos(((M_PI*v)/(2*GLYPH_DIM))*(2*j + 1));
        }
    }
    
    
    alphalookup = (double **)malloc(sizeof(double *) * GLYPH_DIM);
    for (int i = 0; i < GLYPH_DIM; i++)
    {
        alphalookup[i] = (double *)malloc(sizeof(double) * GLYPH_DIM);
    }
    
    // populate alpha lookup table
    for(int i = 0; i < GLYPH_DIM; i++)
    {
        for(int j = 0; j < GLYPH_DIM; j++)
        {
            alphalookup[i][j] = [self alpha:(double)i] * [self alpha:(double)j];
        }
    }
    
    cosalphalookup = (double ****)malloc(sizeof(double ***) * GLYPH_DIM);
    for (int i = 0; i < GLYPH_DIM; i++)
    {
        cosalphalookup[i] = (double ***)malloc(sizeof(double **) * GLYPH_DIM);
        for (int j = 0; j < GLYPH_DIM; j++)
        {
            cosalphalookup[i][j] = (double **)malloc(sizeof(double *) * GLYPH_DIM);
            for (int k = 0; k < GLYPH_DIM; k++)
            {
                cosalphalookup[i][j][k] = (double *)malloc(sizeof(double) * GLYPH_DIM);
            }
        }

    }
    
    for(int u = 0; u < GLYPH_DIM; u++)
    {
        for(int v = 0; v < GLYPH_DIM; v++)
        {
            for(int i = 0; i < GLYPH_DIM; i++)
            {
                for(int j = 0; j < GLYPH_DIM; j++)
                {
                    cosalphalookup[u][v][i][j] =  alphalookup[i][j]*
                                                    cos(((M_PI*u)/(2*GLYPH_DIM))*(2*i + 1))*
                                                    cos(((M_PI*v)/(2*GLYPH_DIM))*(2*j + 1));
                }
            }
        }
    }
    
    _dctCoeffCheckLimit = 0;
    dctWeights = (double **)malloc(sizeof(double *) * GLYPH_DIM);
    for (int u = 0; u < GLYPH_DIM; u++)
    {
        dctWeights[u] = (double *)malloc(sizeof(double) * GLYPH_DIM);
        
        for (int v = 0; v < GLYPH_DIM; v++)
        {
            double dist = sqrt((double)(u*u + v*v));
            double weight = sqrt(pow(0.5, dist));
            dctWeights[u][v] = weight;
            
            if (weight > DCT_WEIGHT_LIMIT)
            {
                _dctCoeffCheckLimit++;
            }
        }
    }
    
    int cMult = 256/COLOR_LEVELS;
    pixBrightness = (double ***)malloc(sizeof(double **) * COLOR_LEVELS);
    for (int r = 0; r < COLOR_LEVELS; r++)
    {
        pixBrightness[r] = (double **)malloc(sizeof(double*) * COLOR_LEVELS);
        for (int g = 0; g < COLOR_LEVELS; g++)
        {
            pixBrightness[r][g] = (double *)malloc(sizeof(double) * COLOR_LEVELS);
            
            for (int b = 0; b < COLOR_LEVELS; b++)
            {
                double red = (double)r * (double)cMult;
                double green = (double)g * (double)cMult;
                double blue = (double)b * (double)cMult;
                
                double dist;
                dist = sqrt((double)red*(double)red + (double)green*(double)green + (double)blue*(double)blue);
                dist  = dist / sqrt(3.0);
                pixBrightness[r][g][b] = dist;
            }
            
        }
    }
    
    
    
    _imgIndices = (unsigned char *)malloc(sizeof(unsigned char) * 1010);
    
    _sortedGlyphDCValues = (double *)malloc(sizeof(double) * 256);
    _sortedGlyphIndices = (int *)malloc(sizeof(int) * 256);
    
    _resultView = [[UIView alloc] init];
    _resultView.frame = CGRectMake(0, 200, 320, 200);
    _resultView.backgroundColor = [UIColor whiteColor];
    [self.view addSubview:_resultView];
    
    _fragmentImageViews = [[NSMutableArray alloc] init];
    
    for (int y = 0; y < 200; y+= GLYPH_OUT_DIM)
    {
        for (int x = 0; x < 320; x+= GLYPH_OUT_DIM)
        {
            UIImageView *frag = [[[UIImageView alloc] initWithFrame:CGRectMake(x, y, GLYPH_OUT_DIM, GLYPH_OUT_DIM)] autorelease];
            [_fragmentImageViews addObject:frag];
            [_resultView addSubview:frag];
        }
    }
    
    _glyphImages = [[NSMutableArray alloc] init];
    
    for (int i = 0; i < 256; i++)
    {
        NSString *imgFname;
        if (i < 128)
        {
            imgFname = [NSString stringWithFormat:@"%d.png",i];
        }
        else
        {
            imgFname = [NSString stringWithFormat:@"%d_r.png",i-128];
        }
        UIImage *thisImg = [UIImage imageNamed:imgFname];
        
        [_glyphImages addObject:thisImg];
    }
    
    self.imgPicker = [[UIImagePickerController alloc] init];
    self.imgPicker.allowsEditing = NO;
    self.imgPicker.delegate = self;
    self.imgPicker.sourceType = UIImagePickerControllerSourceTypeCamera;
    //self.imgPicker.showsCameraControls = NO;
    
    [self prepareGlyphSignatures];
    
    _captureSession = [[AVCaptureSession alloc] init];
    _captureSession.sessionPreset = AVCaptureSessionPreset640x480;
    [self addVideoInput];
    [self addVideoPreviewLayer];
    [self addVideoOutput];
    //[self addStillImageOutput];
    
    /*
    CGRect layerRect = [[[self view] layer] bounds];
    [_previewLayer setBounds:layerRect];
    [_previewLayer setPosition:CGPointMake(CGRectGetMidX(layerRect),
                                          CGRectGetMidY(layerRect))];
    */
    CGRect layerRect = CGRectMake(0, -42.5, 120, 160);
    [_previewLayer setBounds:layerRect];
    [_previewLayer setPosition:CGPointMake(CGRectGetMidX(layerRect),
                                           CGRectGetMidY(layerRect))];
    _previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill;
    [[[self view] layer] addSublayer:_previewLayer];
    
    UIView *maskView = [[[UIView alloc] initWithFrame:CGRectMake(0, 75.0, 120, 42.5)] autorelease];
    maskView.backgroundColor = [UIColor blackColor];
    [self.view addSubview:maskView];
    
    [_captureSession startRunning];
    
    //_grabbedImage = [[UIImageView alloc] init];
    //_grabbedImage.frame = CGRectMake(0, 0, 320, 200);
    //[self.view addSubview:_grabbedImage];
    
    _grabButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    _grabButton.frame = CGRectMake(0, 400, 320, 80);
    [_grabButton addTarget:self action:@selector(captureStillImage) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:_grabButton];
}

- (void)addVideoInput {
	//AVCaptureDevice *videoDevice = [AVCaptureDevice defaultDeviceWithMediaType:AVMediaTypeVideo];
	NSArray *videoDevices = [AVCaptureDevice devicesWithMediaType:AVMediaTypeVideo];
    AVCaptureDevice *videoDevice = nil;
    for (AVCaptureDevice *dev in videoDevices)
    {
        if (dev.position == AVCaptureDevicePositionFront)
        {
            videoDevice = dev;
        }
    }
    
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

- (void)addVideoOutput
{
    _dataOutput = [AVCaptureVideoDataOutput new];
    _dataOutput.alwaysDiscardsLateVideoFrames = YES;
    _dataOutput.videoSettings = [NSDictionary dictionaryWithObject:[NSNumber numberWithUnsignedInt:kCVPixelFormatType_32BGRA]
                                                            forKey:(NSString *)kCVPixelBufferPixelFormatTypeKey];
    
    dispatch_queue_t outQueue = dispatch_queue_create("com.sugoisystems.captureQueue", NULL);
    [_dataOutput setSampleBufferDelegate:self queue:outQueue];
    
    NSLog(@"cant _dataOutput? %i", [_captureSession canAddOutput:_dataOutput]);
    [_captureSession addOutput:_dataOutput];
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

- (void)captureOutput:(AVCaptureOutput *)captureOutput
didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer
       fromConnection:(AVCaptureConnection *)connection
{
    if (_shouldCaptureNow)
    {
        double currTime = CACurrentMediaTime();
        // if (currTime > _nextCaptureTime)
        {
            _nextCaptureTime = currTime + 1.0;
            //_shouldCaptureNow = NO;
            CVImageBufferRef imgBuf = CMSampleBufferGetImageBuffer(sampleBuffer);
            NSLog(@"capturing now!");
            
            UIImage *image = [self getImageFromSampleBuffer:imgBuf];
            dispatch_sync(dispatch_get_main_queue(), ^{
                self.theImage = image;
                [image release];
                [self processImage];
            });
        }
    }
}

- (UIImage *)getImageFromSampleBuffer:(CVImageBufferRef)frame
{
    CIImage *img = [CIImage imageWithCVPixelBuffer:frame options:NULL];
    
    CGFloat bh = (CGFloat)CVPixelBufferGetHeight(frame);
    CGFloat bw = (CGFloat)CVPixelBufferGetWidth(frame);
    CGFloat s = MIN(bh, bw);
    
    CGRect r = CGRectMake((bw - s) / 2.0f, (bh - s) / 2.0f, s, s);
    
    CIContext *_ciContext = [[CIContext contextWithOptions:nil] retain];
    CGImageRef cimg = [_ciContext createCGImage:img fromRect:r];
    
    UIImageOrientation orient;
    orient = UIImageOrientationRight;
    
    UIImage *vimg = [UIImage imageWithCGImage:cimg scale:1 orientation:orient];
    CGImageRelease(cimg);
    [_ciContext release];
    
    return vimg;
}



- (void)captureStillImage
{
    _shouldCaptureNow = YES;
    //_previewLayer
    
    /*
    double startTime = CACurrentMediaTime();
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
        self.theImage = image;
        [image release];
        [self processImage];
        double endTime = CACurrentMediaTime();
        NSLog(@"total capture/process %f seconds",endTime-startTime);
        //[self performSelector:@selector(captureStillImage) withObject:nil afterDelay:0.0];
    }];
    */
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
