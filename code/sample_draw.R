# SELECTING AN SPATIALLY BALANCED SAMPLE FOR FRACTIONAL COVER MODEL VALIDATION #
# 2023-11-17

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
data_path <- "data"

# The path to write the sampling design to once this is all complete
# Change this to a full path if output isn't a subfolder in your working
# directory
output_path <- "output"


#### DATA ######################################################################
# First, read in the LMF points which are in the GDB
lmf_points_2022 <- sf::st_read(dsn = paste0(data_path, "/",
                                            "LMF2022Ingest.gdb"),
                               layer = "POINTCOORDINATES")

# Adding in variables that are present in the rest of the points' attributes
# The year is important because it'll be used to stratify the sampling design
# and the ProjectKey is important because only points associated with BLM_AIM
# should be considered for the sampling design
lmf_points_2022[["year"]] <- "2022"
lmf_points_2022[["ProjectKey"]] <- "BLM_AIM"

# This uses the package trex (https://github.com/landscape-data-commons/trex)
# to access the Landscape Data Commons and download the coordinates for all
# points in the database
all_other_aim_lmf_points_headers <-  trex::fetch_ldc(data_type = "header",
                                                     timeout = 60,
                                                     take = 10000,
                                                     delay = 500,
                                                     verbose = TRUE)

# The points are in tabular format and need to be converted into an sf object
all_other_aim_lmf_points <- sf::st_as_sf(x = all_other_aim_lmf_points_headers,
                                         coords = c("Longitude_NAD83",
                                                    "Latitude_NAD83"),
                                         crs = "+proj=longlat +ellps=GRS80 +towgs84=0,0,0,0,0,0,0 +no_defs +type=crs")

# Again, the sampling design needs to be stratified by year
# This will extract the year from the DateVisited variable
all_other_aim_lmf_points[["year"]] <- stringr::str_extract(string = all_other_aim_lmf_points$DateVisited,
                                                                      pattern = "^20\\d{2}")

# Combine the two sf objects into a single set of points and make sure that the
# CRS is appropriate for spsurvey::grts()
all_points <- sf::st_transform(dplyr::bind_rows(all_other_aim_lmf_points,
                                                lmf_points_2022),
                               crs = projection_aea)

# Filter the points down to only those which have an associated year (some may
# have had malformed dates) and the ProjectKey "BLM_AIM" then keep only the
# variables PrimaryKey (the unique identifier) and year.
all_points <- dplyr::select(.data = dplyr::filter(.data = all_points,
                                                  !is.na(year),
                                                  ProjectKey == "BLM_AIM"),
                                                  PrimaryKey,
                                                  year)

#### DESIGN ####################################################################
# spsurvey::grts() takes a named vector of sample sizes where the names
# correspond to the strata and the values to the number of points to draw in
# each stratum

# The easiest way to get this is to use table() which will provide a named count
# of points associated with each value in the variable year then multiply those
# counts by 0.1 to get the desired sample sizes
sample_size_vector <- ceiling(table(all_points$year) * 0.1)

# Only years in which there were at least 100 points sampled should be included
# in the sampling design
sample_size_vector <- sample_size_vector[table(all_points$year) >= 100]

# Set a seed numebr so that this is reproducible
set.seed(46290)

# Draw the sample. It shouldn't be necessary, but just in case the points are
# filtered to only include those corresponding to qualifying years
# Because this isn't a design in which there might be later rejections, only
# "base" points are being drawn
sample <- spsurvey::grts(sframe = dplyr::filter(all_points,
                                                year %in% names(sample_size_vector)),
                         n_base = sample_size_vector,
                         stratum_var = "year")

#### WRITING ###################################################################
# Write the sample out to a usable format, in this case an ESRI shapefile,
# making sure that the sample points are in the same projection that the input
# points.
sf::st_write(obj = sf::st_transform(x = dplyr::select(.data = sample$sites_base,
                                                      PrimaryKey,
                                                      year),
                                    crs = sf::st_crs(lmf_points_2022)),
             dsn = output_path,
             layer = "validation_sample_points",
             driver = "ESRI shapefile",
             append = FALSE)
