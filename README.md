
<!-- README.md is generated from README.Rmd. Please edit that file -->
contourPolys
============

The goal of contourPolys is to create polygons via contourLines.

Example
-------

This seems to work

``` r
library(raster)
#> Loading required package: sp
library(dplyr)
#> 
#> Attaching package: 'dplyr'
#> The following objects are masked from 'package:raster':
#> 
#>     intersect, select, union
#> The following objects are masked from 'package:stats':
#> 
#>     filter, lag
#> The following objects are masked from 'package:base':
#> 
#>     intersect, setdiff, setequal, union
p2seg <- function(x) cbind(head(seq_len(nrow(x)), -1), 
                           tail(seq_len(nrow(x)), -1))
sf_explode <- function(x) {
  d <- sf::st_coordinates(x) %>% 
    tibble::as_tibble()
  Ls <- grep("^L", names(d))
  paster <- function(...) paste(..., sep = "-")
  dl <- d[-Ls] %>% mutate(path = do.call(paster, d[Ls])) %>% 
    split(.$path) 
  ll <- purrr::map(dl, ~lapply(split(t(p2seg(.x)), rep(seq_len(nrow(.x)-1), each = 2L)), 
                               function(idx) sf::st_linestring(as.matrix(.x[idx, c("X", "Y")])))) 
  sf::st_sfc(unlist(ll, recursive = FALSE))
}


r <- extend(raster(volcano), 1, value = min(volcano)- 1)
cl <- rasterToContour(r, levels = seq(min(volcano) - 0.5, max(volcano) - 10, by = 20))
x <- sf_explode(sf::st_as_sf(cl))

library(sf)
#> Linking to GEOS 3.6.2, GDAL 2.2.4, proj.4 4.9.3
p <- st_polygonize(st_union(x))
a <- st_cast(p)
st_overlaps(a)
#> Sparse geometry binary predicate list of length 6, where the predicate was `overlaps'
#>  1: (empty)
#>  2: (empty)
#>  3: (empty)
#>  4: (empty)
#>  5: (empty)
#>  6: (empty)
plot(a, col = viridis::viridis(length(a)))
```

![](README-unnamed-chunk-2-1.png)

Meh ...

But, maybe we can marching squares - here's a rough stab at the codes for the cases:

``` r
library(raster)

r <- raster(volcano)

v <- 120
#contour(r, level = v)

mask <- r >= v
plot(mask)
twobytwo <- function(x, row = 1) {
 ind <-  matrix(c(1, 2) + c(0, 0, rep(ncol(r), 2)), nrow = 4, ncol = ncol(r) - 1) + 
    cellFromRow(r, 1) - 1
 ind + ncol(r) * (row-1)
}
plot(mask)
codes <- vector("list", nrow(r)-1)
pak <- function(x) {
  as.integer(packBits(as.integer(c(x, 0, 0, 0, 0)), type = "raw"))
}
options(warn = -1)
for (row in seq_len(nrow(mask)-1)) {
  codes[[row]] <- apply(matrix(extract(mask, c(twobytwo(r, row))), nrow = 4), 2, pak)
}
 

lookup_table <- function(code, coord, res) {
  ## build the segment on the coord with the given resolution
  ## case 1
  xy1 <- c(res[1]/2, 0)
  xy2 <- c(0, -res[2]/2)
  
  ## case2
  xy1 <- c(0, -res[2]/2)
  xy2 <- c(0, res[1]/2)
  
  ## etc, figure out cunning lookup
  coords <- rbind(coord, coord)
  
} 
```

Installation
------------

You can install contourPolys from github with:

``` r
# install.packages("devtools")
devtools::install_github("hypertidy/contourPolys")
```

This is a basic example which shows you how to solve a common problem:

``` r

library(raster)
r <- aggregate(raster(volcano), fact = 2, fun = median) %/% 20
r <- tabularaster:::set_indextent(r)
plot(r, asp = "")
#val <- cellStats(r, min)
#r <- extend(r, 1, value = val-1)

x <- list(x = xFromCol(r), y = rev(yFromRow(r)), z = t(as.matrix(flip(r, "y"))))
clevels <- sort(na.omit(unique(values(r))))
cl <- contourLines(x, levels = clevels)
bound <- as(as(extent(r), "SpatialPolygons"), "SpatialLines")@lines[[1]]@Lines

resx <- res(r)[1]
resy <- res(r)[2]

## note order here to trace around correctly
## and has to be centres to align to contourLines' assumption
xcentres <-  xFromCol(r) ##seq(xmin(r), xmax(r), length.out = ncol(r) + 1)
ycentres <-  rev(yFromRow(r)) #seq(ymin(r), ymax(r), length.out = nrow(r) + 1)
boundary_coords <- rbind(
                    cbind(xmin(r), ycentres), 
                    cbind(xcentres, ymax(r)), 
                    cbind( xmax(r), rev(ycentres)), 
                    cbind(rev(xcentres), ymin(r))
)
nearest_point <- function(coords, pt) {
  distances <- sqrt((coords[,1] - pt[1])^2 + 
                      (coords[,2] - pt[2])^2)
  coords[which.min(distances), , drop = FALSE]
  
}
mesh_lines <- vector("list", length(cl))
 
for (i in seq_along(cl)) {
  xxs <- cl[[i]]$x
  yys <- cl[[i]]$y
  npts <- length(xxs)
  bounded <- 
    abs(xxs[1] - xxs[npts]) < sqrt(.Machine$double.eps) &&
    abs(yys[1] - yys[npts]) < sqrt(.Machine$double.eps)
  ## create polygon if bounded
  if (bounded) {
    mesh_lines[[i]] <- cbind(xxs, yys)
  } else {
    ## otherwise insert extra coordinates to nearest side
    pt1 <- nearest_point(boundary_coords, cbind(xxs[1], yys[1]))
    pt2 <- nearest_point(boundary_coords, cbind(xxs[npts], yys[npts]))
    mesh_lines[[i]] <- rbind(pt1, cbind(xxs, yys), pt2)
   }
}

plot(r, asp = "")
lapply(mesh_lines, lines)
## note this must be a single multi-line
ll <- sp::Lines(lapply(c(mesh_lines, list(boundary_coords)), sp::Line), "1")
#x <- sp::SpatialLines(lapply(seq_along(ll), function(i) sp::Lines(ll[[i]], as.character(i))))
x <- sp::SpatialLines(list(ll))

## now we have the right structures
ct <- sf::st_cast(sfdct::ct_triangulate(sf::st_as_sf(x)))
library(sf)
sp_ct <- as(ct, "Spatial")
sp_ct$id <- seq_len(nrow(sp_ct))
sp_ct$contour_level <- clevels[findInterval(extract(r, do.call(rbind, lapply(sp_ct@polygons, function(x) x@labpt))), 
             clevels)]
sp_ct$id <- NULL
ct <- rgeos::gUnionCascaded(sp_ct, sp_ct$contour_level)
plot(st_as_sf(ct))
## now merge
#library(dplyr)
st_as_sf(sp_ct) %>% group_by(contour_level) %>% mutate(geometry = st_combine(geometry))
```
