# Creating a spatially balanced sample for fractional cover model validation

Many fractional cover models are trained using data from the Bureau of Land Managment Assessment, Inventory, and Monitoring (BLM AIM) program and Natural Resources Conservation Service (NRCS) the Landscape Monitoring Framework (LMF).

This code will draw a spatially-balanced sample from the AIM and LMF points sampled through 2022. The sample draw consists of 10% of the points sampled in each year which had at least 100 points sampled.

## Output
The sample draw is available in the output folder (most easily accessible as [a ZIP file](https://github.com/Landscape-Data-Commons/FracCover_Independent_Validation/blob/main/output/model_validation_points_20131113.zip) and consists of a geodatabase with a feature class containing the points selected. You can reproduce the draw using the code and source data.
