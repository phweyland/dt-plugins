# darktable-Group-Metadata
darktable plugin - group derived images to master - Apply master images metadata to derived images

tested with Windows and darktabel 2.4.1

set master: apply darktable|group|master tag to selected images

group to master: group each selected image with its master image.
  A master image is recognized as follow:
    - belongs to parent folder of selected image
    - tagged as darktable|group|master
    - filename (without extension) included in selected image filename. Examples:
      20180315_BH.nef can be mater image of 20180315_BH.jpg or 20180315_BH-NVf.jpg

update from master: copy master image's metadata to selected images, based on the following switches:
  rate & color
  metadata
  GPS data
  tags

copy: copy selected image's metadata
paste: paste copied metadata to selected images, based on previous switches.
clear: clear selected images' metadata, based on previous switches.
