# Maintainers Guide

This page contains information about the GMT data server.

## Naming of the remote files

The remote files have names following the pattern:

	planet_name_rru_reg.suffix

in which:

- *planet* can be *earth*, *moon*, *mars* et al.
- *name* is the name of the dataset, like *relief*, *mask*
- *rru* is the grid resolution. *u* is the unit, and can be **d** (degree), **m** (minute) or **s** (second)
- *reg* is the grid registration. It can be either **p** (pixel) or **g** (gridline)
- *suffix* is the grid suffix. It can be *grd* or *tif*.

## Grid and Image domains

All grid and image products shall use longitude range ±180 and not 0-360.
The recipe files shall deal with any longitude conversions needed.
Coverage grids (to fill in missing tiles, for instance) shall have the
same range as the grid it is filling in for.

## Tiles masks

Grids holding information about presence of absence of 1x1 degree tiles
shall be in 0-360 range format and use gridline-registration so that
we can check the result using the lower-left integer coordinate of the
grid cell rather than the center coordinate (off by 0.5) in a pixel grid.

## Grid registrations

GMT serves up both pixel and gridline registered files, if possible.

If users don't specify a registration, the default registration will be returned.

- GMT<=6.0 returns the gridline-registered version for backward compatibility.
- GMT>=6.1 returns the pixel-registered version unless only the gridline-registered
  file is available.

For plotting modules both the resolution *rru* and the registration *reg* are optional,
whereas for grid processing modules you must indicate exactly what you want. The plot
modules, if given the tag @earth_relief will use the map specifications and the GMT
default setting **GMT_GRAPHICS_DPU** to determine what *rru* will provide the desired
resolution.

## Organization of directories

The layout of the directories and files on the data server look like:

```
cache: [Odds and ends used for tests and examples tutorial etc.]
geography: [The coastline data]
	dcw
	gshhg
server: [Data served by us]
	earth
		earth_age
		earth_day
		earth_night
		earth_mask
		earth_relief
		earth_synbath
		...
	moon
		...
	mars
		...
```

## Manual curl test of server

To just copy a file, say the gmt_data_server.txt file from oceania, try

```
curl -ks  http://oceania.generic-mapping-tools.org/gmt_data_server.txt
```

## Testing new remote data sets

The testing server is called *candidate.generic-mapping-tools.org* so if new files are
placed there and **GMT_DATA_SERVER** is set to *candidate* then gmt will try to get
files from the *candidate* directory on the server.  Once files are moved to the
official *data* directory then the test directory can be cleaned out with `candidate-delete`.
**Note**: *candidate* and *oceania* are the same remote data server but the two URLs point to
different sub-directories.

## Adding more data

The script srv_downsampler.sh reads a recipe file and downloads and resamples the data
set (grid or image).  Then, the script srv_tiler.sh creates a
tiled version of any global data set that is too large.  This script also produces
the metadata information section that will go into gmt_data_sever.txt.  Once the data
on the candidate server is acceptable then `make release-server` will copy files from
*candidate* to *data* and rebuild the gmt_data_sever.txt index file.

## Mirror the data server

To build a mirror of the GMT data server, you need to run one of the following commands
to synchronize all files to your local mirror server:

```
rsync -av --delete rsync://oceania.generic-mapping-tools.org/gmtdata /your/local/gmtdata
```
or
```
rsync -av --delete gmtserver.soest.hawaii.edu::gmtdata /your/local/gmtdata
```

To keep all files up-to-date, you need to run the above command periodically (e.g., daily)
via crontab jobs:

```
0 0 * * *	rsync -a --delete rsync://oceania.generic-mapping-tools.org/gmtdata /your/local/gmtdata
```
