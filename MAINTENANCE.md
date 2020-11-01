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

## Grid registrations

GMT serves up both pixel and gridline registered files if possible.

If users don't specify a registration, the default registration will be returned.

- GMT<=6.0 returns the gridline-registered version for backward compatibility.
- GMT>=6.1 returns the pixel-registered version unless only the gridline-registered
  file is available.

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
		...
	moon
		...
	mars
		...
```
