

#import "GLView.h"

#define QUAD_VERTICES 				4
#define QUAD_COORDS_PER_VERTEX      3
#define QUAD_TEXCOORDS_PER_VERTEX 	2
#define QUAD_VERTEX_BUFSIZE 		(QUAD_VERTICES * QUAD_COORDS_PER_VERTEX)
#define QUAD_TEX_BUFSIZE 			(QUAD_VERTICES * QUAD_TEXCOORDS_PER_VERTEX)

const GLfloat quadVertices[] = {
    -1, -1, 0,
     1, -1, 0,
    -1,  1, 0,
     1,  1, 0 };


@interface GLView(Private)
- (void)setupGL;
- (void)initShaders;
- (BOOL)buildShader:(Shader *)shader src:(NSString *)src;
- (void)drawMarker:(ocv_ar::Marker *)marker;
@end

@implementation GLView

@synthesize markers;
@synthesize markerProjMat;
@synthesize markerScale;
@synthesize showMarkers;

#pragma mark init/dealloc

- (id)initWithFrame:(CGRect)frame {
    // create context
    EAGLContext *ctx = [[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2] autorelease];
    [EAGLContext setCurrentContext:ctx];
    
    // init
    self = [super initWithFrame:frame context:ctx];
    
    if (self) {
        // defaults
        glInitialized = NO;
        showMarkers = YES;
        
        markerProjMat = NULL;
        
        memset(markerScaleMat, 0, sizeof(GLfloat) * 16);
        [self setMarkerScale:1.0f];
//        dispFrameTexId = 0;
        
        // configure
        [self setOpaque:NO];
        
        [self setDrawableColorFormat:GLKViewDrawableColorFormatRGBA8888];
        [self setDrawableDepthFormat:GLKViewDrawableDepthFormat24];
        [self setDrawableStencilFormat:GLKViewDrawableStencilFormat8];
    }
    
    return self;
}

#pragma mark parent methods

- (void)drawRect:(CGRect)rect {
    if (!glInitialized) return;
    
    // Clear the framebuffer
    glClearColor(0.0f, 0.0f, 0.0f, 0.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glViewport(0, 0, viewportSize.width, viewportSize.height);
    
    if (!showMarkers) return;
    
    markerDispShader.use();
    
    if (markerProjMat) {
//        NSLog(@"GLView: drawing %lu markers", markers.size());
        for (vector<ocv_ar::Marker *>::const_iterator it = markers.begin();
             it != markers.end();
             ++it)
        {
            [self drawMarker:(*it)];
        }
    }
}

- (void)resizeView:(CGSize)size {
    NSLog(@"GLView: resizing to frame size %dx%d",
          (int)size.width, (int)size.height);
    
    if (!glInitialized) {
        NSLog(@"GLView: initializing GL");
        
        [self setupGL];
    }
    
    // handle retina displays, too:
    float scale = [[UIScreen mainScreen] scale];
    viewportSize = CGSizeMake(size.width * scale, size.height * scale);
    
    [self setNeedsDisplay];
}

#pragma mark public methods

- (void)setMarkerScale:(float)s {
    markerScale = s;
    
    // set 4x4 matrix diagonal to s
    // markerScaleMat must be zero initialized!
    for (int i = 0; i < 3; ++i) {
        markerScaleMat[i * 5] = s * 0.5f;
    }
    markerScaleMat[15] = 1.0f;
}

#pragma mark private methods

- (void)drawMarker:(ocv_ar::Marker *)marker {
	// set matrixes
	glUniformMatrix4fv(shMarkerProjMat, 1, false, markerProjMat);
	glUniformMatrix4fv(shMarkerModelViewMat, 1, false, marker->getPoseMatPtr());
    glUniformMatrix4fv(shMarkerTransformMat, 1, false, markerScaleMat);
    
    int id = marker->getId();
    char r = 2 << id;
    char g = 4 << id;
    char b = 8 << id;
    float markerColor[] = { (float)r / 255.0f,
                            (float)g / 255.0f,
                            (float)b / 255.0f,
                            0.75f };
	glUniform4fv(shMarkerColor, 1, markerColor);
    
	// set geometry
	glEnableVertexAttribArray(shAttrPos);
	glVertexAttribPointer(shAttrPos,
						  QUAD_COORDS_PER_VERTEX,
						  GL_FLOAT,
						  GL_FALSE,
						  0,
						  quadVertices);
    
    // draw
    glDrawArrays(GL_TRIANGLE_STRIP, 0, QUAD_VERTICES);
    
    // cleanup
    glDisableVertexAttribArray(shAttrPos);
}

- (void)setupGL {
    [self initShaders];
    
    glDisable(GL_CULL_FACE);
    
    glInitialized = YES;
}

- (void)initShaders {
    [self buildShader:&markerDispShader src:@"marker"];
    shMarkerProjMat = markerDispShader.getParam(UNIF, "uProjMat");
    shMarkerModelViewMat = markerDispShader.getParam(UNIF, "uModelViewMat");
    shMarkerTransformMat = markerDispShader.getParam(UNIF, "uTransformMat");
    shMarkerColor = markerDispShader.getParam(UNIF, "uColor");
}

- (BOOL)buildShader:(Shader *)shader src:(NSString *)src {
    NSString *vshFile = [[NSBundle mainBundle] pathForResource:[src stringByAppendingString:@"_v"]
                                                        ofType:@"glsl"];
    NSString *fshFile = [[NSBundle mainBundle] pathForResource:[src stringByAppendingString:@"_f"]
                                                        ofType:@"glsl"];
    
    const NSString *vshSrc = [NSString stringWithContentsOfFile:vshFile encoding:NSASCIIStringEncoding error:NULL];
    if (!vshSrc) {
        NSLog(@"GLView: could not load shader contents from file %@", vshFile);
        return NO;
    }
    
    const NSString *fshSrc = [NSString stringWithContentsOfFile:fshFile encoding:NSASCIIStringEncoding error:NULL];
    if (!fshSrc) {
        NSLog(@"GLView: could not load shader contents from file %@", fshFile);
        return NO;
    }
    
    return shader->buildFromSrc([vshSrc cStringUsingEncoding:NSASCIIStringEncoding],
                                [fshSrc cStringUsingEncoding:NSASCIIStringEncoding]);
}

@end
