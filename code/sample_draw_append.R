# SELECTING AN SPATIALLY BALANCED SAMPLE FOR FRACTIONAL COVER MODEL VALIDATION #
# 2024-09-23

# This will produce a spatially-balanced sampling design made of a subset of the
# available BLM AIM and LMF points from years in which at least 100 points were
# sampled. The design will be stratified by year and each stratum/year will
# contain 10% of the points available in that year, e.g., if there are 4,000
# points that were sampled in 2016 then the sampling design stratum "2016" will
# contain 400 points.

#### CONFIGURATION #############################################################
# spsurvey::grts() needs the incoming points to be in a geographic projection,
# so we'll use Albers Equal Area
projection_aea <- sp::CRS("+proj=aea +lat_1=29.5 +lat_2=45.5 +lat_0=37.5 +lon_0=-96 +x_0=0 +y_0=0 +ellps=GRS80 +datum=NAD83 +units=m +no_defs")

# The path to the incoming data. This is necessary because some LMF data have
# been ingested into a GDB but not added to the national database yet
# Change this to a full path if data isn't a subfolder in your working directory
data_path <- "~/Projects/AIM/Data/AIMTerrestrialPub1-15-26.gdb/AIMTerrestrialPub1-15-26.gdb/"

# The path to write the sampling design to once this is all complete
# Change this to a full path if output isn't a subfolder in your working
# directory
output_path <- "output"


#### DATA ######################################################################

# This uses the package trex (https://github.com/landscape-data-commons/trex)
# to access the Landscape Data Commons and download the coordinates for all
# points in the database
all_other_lmf <- sf::st_read(dsn = data_path,
                             layer = "AIM_TerrestrialLMF__I_Indicators" ) |> dplyr::select(PrimaryKey, Latitude_NAD83, Longitude_NAD83, DateVisited)

all_other_aim <- sf::st_read(dsn = data_path,
                             layer = "AIM_TerrestrialTerradat__I_Indicators") |> dplyr::select(PrimaryKey, Latitude_NAD83, Longitude_NAD83, DateVisited)


# Combine the all datasets objects into a single set of points and make sure that the
# CRS is appropriate for spsurvey::grts()
all_points <- sf::st_transform(dplyr::bind_rows(all_other_lmf,all_other_aim),
                               crs = projection_aea)

# Again, the sampling design needs to be stratified by year
# This will extract the year from the DateVisited variable
all_points <- all_points |>
  dplyr::mutate(DateVisited = as.POSIXct(DateVisited, format = "%Y/%m/%d %H:%M", tz = "UTC")) |>
  dplyr::mutate(YearVisited = lubridate::year(DateVisited))|> subset(YearVisited==2024)


#### DESIGN ####################################################################
# spsurvey::grts() takes a named vector of sample sizes where the names
# correspond to the strata and the values to the number of points to draw in
# each stratum

# The easiest way to get this is to use table() which will provide a named count
# of points associated with each value in the variable year then multiply those
# counts by 0.1 to get the desired sample sizes
sample_size_vector <- ceiling(table(all_points$YearVisited) * 0.1)

# Only years in which there were at least 100 points sampled should be included
# in the sampling design
sample_size_vector <- sample_size_vector[table(all_points$YearVisited) >= 100]

# Set a seed numebr so that this is reproducible
set.seed(46290)

# Draw the sample. It shouldn't be necessary, but just in case the points are
# filtered to only include those corresponding to qualifying years
# Because this isn't a design in which there might be later rejections, only
# "base" points are being drawn
sample <- spsurvey::grts(sframe = dplyr::filter(all_points,
                                                YearVisited %in% names(sample_size_vector)),
                         n_base = sample_size_vector,
                         stratum_var = "YearVisited")

# Add in the other NRI points
old_aim <- sf::st_read("output/AIM_reserve_validataion_2024-09-23.csv") |>
 dplyr::mutate(YearVisited = as.numeric(YearVisited))

sample_points <- dplyr::bind_rows(dplyr::select(.data = sample$sites_base,
                                                PrimaryKey,
                                                YearVisited),
                                  dplyr::select(.data = old_aim,
                                                PrimaryKey,
                                                YearVisited))


#### WRITING ###################################################################
# Write the sample out to a usable format, in this case an ESRI shapefile,
# making sure that the sample points are in the same projection that the input
# points.
write.csv(sample_points,
          paste0("output/AIM_reserve_validation_", Sys.Date(), ".csv"),
          row.names = F)

