% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/RcppExports.R
\name{fcontour_sf}
\alias{fcontour_sf}
\title{Filled contour}
\usage{
fcontour_sf(x, y, z, c)
}
\arguments{
\item{x}{vector x coordinate}

\item{y}{vector x coordinate}

\item{z}{vector z matrix}
}
\description{
Filled contour
}
\examples{
library(raster)
  data("topo", package = "contourPolys")
  levels <- c(-6000, -4000, -2000, 0, 2000, 4000)
  fc <- fcontour_sf(xFromCol(topo), rev(yFromRow(topo)), t(as.matrix(flip(topo, "y"))), c = levels)
## DONE  g <- purrr::map(fc[[1]], ~sf::st_polygon(list(.x)))
  ik <- unlist(fc[[2]])
  library(dplyr)
  x <- st_sf(geometry = st_sfc(fc[[1]]), kk = ik) \%>\% group_by(kk) \%>\% summarize() \%>\% st_cast("MULTIPOLYGON")
  ramp2 <- grDevices::colorRampPalette(c("#54A3D1", "#60B3EB", 
                                         "#78C8F0", "#98D1F5", "#B5DCFF", "#BDE1F0", "#CDEBFA", 
                                         "#D6EFFF", "#EBFAFF", "grey92", "grey94", "grey96", "white"))
    plot(x, col = ramp2(nrow(x)))
}
