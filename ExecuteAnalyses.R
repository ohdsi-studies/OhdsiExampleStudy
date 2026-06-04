# -------------------------------------------------------
#                     PLEASE READ
# -------------------------------------------------------
#
# You must call "renv::restore()" and follow the prompts
# to install all of the necessary R libraries to run this
# project. This is a one-time operation that you must do
# before running any code.
#
# !!! PLEASE RESTART R AFTER RUNNING renv::restore() !!!
#
# -------------------------------------------------------
renv::restore()

# ENVIRONMENT SETTINGS NEEDED FOR RUNNING STUDY ------------
Sys.setenv("_JAVA_OPTIONS"="-Xmx4g") # Sets the Java maximum heap space to 4GB
Sys.setenv("VROOM_THREADS"=1) # Sets the number of threads to 1 to avoid deadlocks on file system

##=========== START OF INPUTS ==========
options(sqlRenderTempEmulationSchema = Sys.getenv("DATABRICKS_SCRATCH_SCHEMA")) # For database platforms that don't support temp tables
cdmDatabaseSchema <- "merative_mdcr.sample_cdm_merative_mdcr" # The database / schema where the data in CDM format live
workDatabaseSchema <- Sys.getenv("DATABRICKS_SCRATCH_SCHEMA") # A database /schema where study tables can be written
cohortTableName <- "ohdsi_example_study_mdcr_sample" # Where the cohorts will be written
resultsFolder <- "e:/git/OhdsiExampleStudy/results" # Where the output files will be written
workFolder <- "e:/git/OhdsiExampleStudy/strategusInternals" # Where the intermediate work files will be written
databaseName <- "MDCR Sample" # Only used as a folder name for results from the study
minCellCount <- 5 # Minimum cell count for inclusion in output tables

# Create the connection details for your CDM
# More details on how to do this are found here:
# https://ohdsi.github.io/DatabaseConnector/reference/createConnectionDetails.html
connectionDetails <- DatabaseConnector::createConnectionDetails(
  dbms = "spark",
  connectionString = glue::glue("jdbc:databricks://{Sys.getenv('DATABRICKS_HOST')}/default;transportMode=http;ssl=1;AuthMech=3;httpPath={Sys.getenv('DATABRICKS_HTTP_PATH')}"),
  user = "token",
  password = Sys.getenv("DATABRICKS_TOKEN")
)

# You can use this snippet to test your connection
#conn <- DatabaseConnector::connect(connectionDetails)
#DatabaseConnector::disconnect(conn)

##=========== END OF INPUTS ==========

##################################
# DO NOT MODIFY BELOW THIS POINT
##################################
config <- config::get()

resultsFolder <- file.path(resultsFolder, databaseName)
workFolder <- file.path(workFolder, databaseName)

analysisSpecifications <- ParallelLogger::loadSettingsFromJson(
  fileName = file.path(config$projectRootFolder, "inst", config$studySpecificationFileName)
)

executionSettings <- Strategus::createCdmExecutionSettings(
  workDatabaseSchema = workDatabaseSchema,
  cdmDatabaseSchema = cdmDatabaseSchema,
  cohortTableNames = CohortGenerator::getCohortTableNames(cohortTable = cohortTableName),
  workFolder = workFolder,
  resultsFolder = resultsFolder,
  minCellCount = minCellCount
  # IF YOU NEED TO RE-RUN A STUDY BUT ONLY WANT TO RUN SPECIFIC MODULES,
  # ADD A COMMA AFTER minCellCount AND USE modulesToExecute:
  # modulesToExecute = c("CohortGeneratorModule", "SelfControlledCaseSeriesModule")
)

if (!dir.exists(resultsFolder)) {
  dir.create(resultsFolder, recursive = T)
}

if (!dir.exists(workFolder)) {
  dir.create(workFolder, recursive = T)
}

ParallelLogger::saveSettingsToJson(
  object = executionSettings,
  fileName = file.path(resultsFolder, "executionSettings.json")
)

Strategus::execute(
  analysisSpecifications = analysisSpecifications,
  executionSettings = executionSettings,
  connectionDetails = connectionDetails
)
