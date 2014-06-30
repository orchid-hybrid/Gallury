#include <string.h>
#include <wand/magick_wand.h>

#include <urweb.h>

uw_Basis_blob* uw_Thumbnailer_thumbnail(uw_context ctx, uw_Basis_file file) {
  uw_Basis_blob *bptr;
  uw_Basis_blob b;
  
  MagickWand *m_wand = NULL;
  MagickBooleanType   status;
  ExceptionType   an_error = 0;
  
  int width,height;
  float bound = 180, s;
  
  unsigned char *data;
  size_t length;
  
  MagickWandGenesis();
  
  m_wand = NewMagickWand();
  status = MagickReadImageBlob(m_wand, file.data.data, file.data.size);
  MagickGetException(m_wand, &an_error);
    if (an_error) {
    MagickWandTerminus();
    return NULL;
    }
  if(status  == MagickFalse) {
    printf("status == MagickFalse\n");
    MagickWandTerminus();
    return NULL;
  }
  
  // Get the image's width and height
  width = MagickGetImageWidth(m_wand);
  height = MagickGetImageHeight(m_wand);
  if(width == 0 || height == 0) {
    printf("width == 0 || height == 0\n");
    MagickWandTerminus();
    return NULL;
  }
  printf("%d %d\n", width, height);
  
  if(width > height)
    s = bound/(float)width;
  else
    s = bound/(float)height;
  width *= s;
  height *= s;
  // make sure they don't underflow
  if(width < 1)width = 1;
  if(height < 1)height = 1;
  
  // Set the image background color to white
  PixelWand *color = NewPixelWand();
  PixelSetColor(color, "white");
  MagickSetImageBackgroundColor(m_wand, color);
  m_wand = MagickMergeImageLayers(m_wand, FlattenLayer);
  
  // Resize the image using the Lanczos filter
  // The blur factor is a "double", where > 1 is blurry, < 1 is sharp
  // I haven't figured out how you would change the blur parameter of MagickResizeImage
  // on the command line so I have set it to its default of one.
  MagickResizeImage(m_wand,width,height,LanczosFilter,1);
  MagickSetFormat(m_wand,"JPG");
  
  // Set the compression quality to 70 (high quality = low compression)
  MagickSetImageCompressionQuality(m_wand,70);
  
  /* Write the new image */
  data = MagickGetImageBlob(m_wand, &length);
  
  b.size = length;
  b.data = uw_malloc(ctx, b.size);
  memcpy(b.data, data, b.size);
  
  /* Clean up */
  if(m_wand)m_wand = DestroyMagickWand(m_wand);
  
  MagickWandTerminus();
  
  bptr = uw_malloc(ctx, sizeof(uw_Basis_blob*));
  *bptr = b;
  
  return bptr;
}
