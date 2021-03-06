## Lets cluserify things

library(parallel)

#lets try 100 to start
c1 = makePSOCKcluster(paste0('licon', 1:50), manual=TRUE, port=4044)


clusterCall(c1, function(){install.packages('devtools', repos='http://cran.rstudio.com')})
clusterCall(c1, function(){install.packages('rLakeAnalyzer', repos='http://cran.rstudio.com')})
clusterCall(c1, function(){install.packages('dplyr', repos='http://cran.rstudio.com')})
clusterCall(c1, function(){install.packages('lubridate', repos='http://cran.rstudio.com')})

clusterCall(c1, function(){library(devtools)})

glmr_install     = clusterCall(c1, function(){install_github('lawinslow/GLMr')})
glmtools_install = clusterCall(c1, function(){install_github('lawinslow/glmtools')})
lakeattr_install = clusterCall(c1, function(){install_github('lawinslow/lakeattributes')})
mdalakes_install = clusterCall(c1, function(){install_github('lawinslow/mda.lakes')})

library(lakeattributes)
library(lubridate)
library(mda.lakes)
library(dplyr)
library(glmtools)



get_nldas_wind_debias = function(fname){
  
  path = get_driver_path(fname, driver_name = 'NLDAS')
  nldas = read.csv(path, header=TRUE)
  nldas$time = as.POSIXct(nldas$time)
  
  after_2001 = nldas$time > as.POSIXct('2001-12-31')
  
  nldas$WindSpeed[after_2001] = nldas$WindSpeed[after_2001] * 0.921
  
  driver_path = tempfile(fileext='.csv')
  write.csv(nldas, driver_path, row.names=FALSE, quote=FALSE)
  return(driver_path)
}

clusterExport(c1, varlist = 'get_nldas_wind_debias')

lakes = read.table(system.file('supporting_files/managed_lake_info.txt', package = 'mda.lakes'), 
                   sep='\t', quote="\"", header=TRUE, as.is=TRUE, colClasses=c(WBIC='character'))

to_run = paste0('WBIC_', lakes$WBIC)



downscale_cal_out = function(site_id){
  
  years = 1979:2012
  
  library(lakeattributes)
  library(mda.lakes)
  library(dplyr)
  library(glmtools)
  library(stringr)
  
  tryCatch({
    fastdir = tempdir()
    if(file.exists('/mnt/ramdisk')){
      fastdir = '/mnt/ramdisk'
    }
    
    run_dir = file.path(fastdir, site_id)
    dir.create(run_dir)
    cat(run_dir, '\n')
    
    bare_wbic = substr(site_id, 6, nchar(site_id))
        
    secchi = get_kd_best(site_id, years=years)
    
    driver_path = get_nldas_wind_debias(paste0(site_id, '.csv'))
    
    driver_path = gsub('\\\\', '/', driver_path)
    
    #run with different driver and ice sources
    
    res = prep_run_glm_kd(bare_wbic, kd=1.7/secchi$secchi_avg, 
                            path=run_dir, 
                            years=sort(years),
                            nml_args=list(
                              dt=3600, subdaily=FALSE, nsave=24, 
                              timezone=-6,
                              csv_point_nlevs=0,
                              snow_albedo_factor=1.1,
                              meteo_fl=driver_path))
    
    wtr = get_temp(file.path(run_dir, 'output.nc'), reference='surface')
    
    wtr$site_id = site_id
      
    unlink(run_dir, recursive=TRUE)
    
    return(wtr)
    
  }, error=function(e){unlink(run_dir, recursive=TRUE);e})
}

groups = split(to_run, ceiling(seq_along(to_run)/100))
out = list()
for(grp in groups){
  tmp = clusterApplyLB(c1,grp, downscale_cal_out)
  out = c(out, tmp)
  cat('iteration\n')
}

#out = clusterApplyLB(c1, to_run[1], downscale_cal_out)



dframes = out[unlist(lapply(out, inherits, what='data.frame'))]

save('dframes', file = '~/NLDAS_2001_wind_ice_fix.Rdata')

out_path = '~/NLDAS_ice_wind_fix'
dir.create(out_path)

for(i in 1:length(dframes)){
  
  cat(i, '\n')  
  d = dframes[[i]]
  site_id = d$site_id[1]
  d$site_id = NULL
  tmp = gzfile(paste0(out_path, '/', site_id, '.tsv.gz'))
  write.table(d, tmp , sep='\t', row.names=FALSE, quote=FALSE)
}

