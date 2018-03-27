# dt-plugins
darktable plugin

Like a lot of people I'm trying to get out of Lightroom. The discovery of
darktable is amazing. It has a lot of interesting features. Openess is not
its smallest quality.

## group Derived Images

  Assume that derived images are stored in a sub-folder of master images.

- Group derived images to master
- Apply master images metadata to derived images

  tested with Windows 10 64-bits and darktable 2.4.1

## file on disk (Exif)

- Export images to a selected folder
- Remove all development metadata
- Add wanted metadata using ExifTool

  tested with Windows 10 64-bits and darktable 2.4.1

## ExifToolWeb.txt

  Not a plugin but an argument file for ExifTool. It does then the same job
  as the previous plugin but probably much faster.

  Command line : path\exiftool.exe -@ path\ExifToolWeb.txt FILES

  tested with Windows 10 64-bits
