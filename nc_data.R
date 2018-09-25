
# SETUP -------------------------------------------------------------------
setwd("C:/Users/Inigo/Documents/Drought_Map")
# FONTS
library(extrafont)
# font_import()
# loadfonts(device = "win")
# windowsFonts()

#NET-CDF LIBRARIES
library(ncdf4)
library(ncdf4.helpers)
library(PCICt)

# GENERAL LIBRARIES
library(readr)
library(dplyr)
library(tidyr)

# MAPS LIBRARIES
library(ggplot2)
library(rworldmap)
library(ggmap)
library(viridis)
library(rgdal)
theme_map <- function(...) {
  theme_minimal() +
    theme(
      text = element_text(family = "Segoe UI", color = "#22211d"),
      axis.line = element_blank(),
      axis.text.x = element_blank(),
      axis.text.y = element_blank(),
      axis.ticks = element_blank(),
      axis.title.x = element_blank(),
      axis.title.y = element_blank(),
      # panel.grid.minor = element_line(color = "#ebebe5", size = 0.2),
      panel.grid.major = element_line(color = "#ebebe5", size = 0.2),
      panel.grid.minor = element_blank(),
      plot.background = element_rect(fill = "#f5f5f2", color = NA), 
      panel.background = element_rect(fill = "#f5f5f2", color = NA), 
      legend.background = element_rect(fill = "#f5f5f2", color = NA),
      panel.border = element_blank(),
      ...
    )
}

# WORLD MAP ---------------------------------------------------------------

worldMap <- getMap(resolution = "high")
country <- c("Spain")
ind <- which(worldMap$NAME %in% country)

map_coords <- data.frame(worldMap@polygons[[ind]]@Polygons[[1]]@coords) %>% 
  SpatialPoints(proj4string = CRS("+proj=longlat")) %>% 
  spTransform(CRS("+init=epsg:32630")) %>% 
  as.data.frame()
colnames(map_coords) <- list("x", "y")


# NET CDF IMPORT ----------------------------------------------------------

filepath <- "C:/Users/Inigo/Documents/Drought_Map/spei48.nc"
drought_df <- nc_open(filepath)

lon <- ncvar_get(drought_df, varid = "lon")
lat <- ncvar_get(drought_df, varid = "lat")
time <- ncvar_get(drought_df, varid = "time")

grid_map <- expand.grid(lon, lat) %>%
  SpatialPoints(proj4string = CRS("+init=epsg:32630")) %>% 
  # spTransform(CRS("+proj=longlat")) %>% 
  as.data.frame() %>% 
  rename(x = Var1, y = Var2)


draw.map <- function(t, drought_df, grid_map, time, coords){
  value <- nc.get.var.subset.by.axes(f = drought_df, v = "value", axis.indices = list(T=t))
  timestamp <- as.Date(as.POSIXct(time[t]*24*60*60, origin="1970-01-01"))
  
  cuts <- list(x=500,y=500)
  grid_map_value <- grid_map %>% 
    mutate(value = as.vector(value)) %>% 
    drop_na() %>% 
    mutate(value = ifelse(value > 3, 3, ifelse(value < (-3),-3, value)))
  
  if(nrow(grid_map_value)!=0){
    g <- grid_map_value %>% 
      mutate(xg = cut(x, breaks = cuts$x, labels = F),
             yg = cut(y, breaks = cuts$y, labels = F)) %>% 
      group_by(xg,yg) %>% 
      summarise(x = mean(x), y = mean(y), value = mean(value)) %>% 
      ggplot() + 
      geom_point(aes(x = x, y = y, color = value), na.rm=T, size = 1.2, shape=15)+
      # geom_path(data=coords, aes(x = x, y = y, group=group), color="grey20", size=0.5)+
      geom_text(aes(label=timestamp,x = 1000000, y = 4030000),size=7,
                family="Segoe UI",color="#22211d",check_overlap=T)+
      coord_fixed()+
      scale_color_viridis(option = "magma", direction = -1, name = "SPRI", limits=c(-3,3),na.value="black",
                          guide = guide_colorbar(direction = "horizontal", barheight = unit(2, units = "mm"), 
                                                 barwidth = unit(50, units = "mm"), draw.ulim = F, 
                                                 title.position = 'top', title.hjust = 0.5, label.hjust = 0.5))+
      theme_map() + theme(legend.position = "bottom")
    # filename <- paste0("images/spei_",t,".png")
    # ggsave(filename = filename, plot = g, device = "png", width = 9*1.17, height = 9, dpi = 100)
  }
}
t <- 2733
draw.map(t, drought_df, grid_map, time, new_map_coords)

r <- pbapply::pblapply(seq(1,2736,by=4), draw.map, drought_df, grid_map, time, new_map_coords )



# TIMELINE PLOT
# Madrid
example <- list(lat=4474238,lon=440293, name="Madrid")
lat_index <- which.min(abs(lat-example$lat))
lon_index <- which.min(abs(lon-example$lon))
value <- nc.get.var.subset.by.axes(f = drought_df, v = "value", axis.indices = list(X = lon_index, Y = lat_index, T=1:2736))

theme_timeline <- function(...) {
  theme_minimal() +
    theme(
      text = element_text(family = "Segoe UI", color = "#22211d"),
      axis.line = element_blank(),
      axis.text.x = element_blank(),
      # axis.text.y = element_blank(),
      axis.ticks = element_blank(),
      axis.title.x = element_blank(),
      axis.title.y = element_blank(),
      # panel.grid.minor = element_line(color = "#ebebe5", size = 0.2),
      panel.grid.major = element_line(color = "#ebebe5", size = 0.2),
      panel.grid.minor = element_blank(),
      plot.background = element_rect(fill = "#f5f5f2", color = NA), 
      panel.background = element_rect(fill = "#f5f5f2", color = NA), 
      legend.background = element_rect(fill = "#f5f5f2", color = NA),
      panel.border = element_blank(),
      ...
    )
}

draw.timeline <- function(t, time, value, example){
  timestamp <- as.Date(as.POSIXct(time[t]*24*60*60, origin="1970-01-01"))
  time_limits <- as.Date(as.POSIXct(c(time[1],time[2736])*24*60*60, origin="1970-01-01"))
  if(any(!is.na(value[1:t]))){
    g <- data.frame(value=as.vector(value),
                    time=as.Date(as.POSIXct(time*24*60*60, origin="1970-01-01"))) %>% 
      mutate(value = ifelse(value > 3, 3, ifelse(value < (-3),-3, value)),
             in_period = ifelse(time < timestamp, value, 0),
             fill_area = value[t]) %>% 
      ggplot()+
      geom_line(aes(x=time,y=in_period), size=0.65, color="#22211d", na.rm=T)+
      geom_area(aes(x=time,y=in_period, fill=fill_area), na.rm=T, alpha=0.5)+
      geom_hline(yintercept=0)+
      xlab(NULL)+
      ylab("SPEI")+
      theme_timeline()+
      ylim(c(-3,3))+
      xlim(time_limits)+
      scale_fill_viridis(option = "magma", direction = -1, limits=c(-3,3),guide = F)+
      ggtitle(paste0("City: ",example$name))
    
    # filename <- paste0("images/spei_timeline_",example$name,"_",t,".png")
    # ggsave(filename = filename, plot = g, device = "png", width = 9*1.17, height = 3, dpi = 600)
    return(g)
  }
}
t <- 728
draw.timeline(t,time,value,example)

r <- pbapply::pblapply(seq(1,2736,by=50), draw.timeline, time,value,example )

#PLOT COMBINATION
plot.combination <- function(t,drought_df,grid_map,time,new_map_coords,value,example){
  p_map <- draw.map(t, drought_df, grid_map, time, new_map_coords)
  p_timeline <- draw.timeline(t,time,value,example)
  if(!is.null(p_map) & !is.null(p_timeline)){
    g <- gridExtra::grid.arrange(grobs=list(p_map,p_timeline),ncol=1,heights = c(9,2))
    filename <- paste0("images/spei_",example$name,"_",t,".png")
    ggsave(filename = filename, plot = g, device = "png", width = 9*1.18, height = 11, dpi = 100)
  }
}
t <- 728
plot.combination(t,drought_df,grid_map,time,new_map_coords,value,example)
r <- pbapply::pblapply(seq(1,2736,by=4), plot.combination,drought_df,grid_map,time,new_map_coords,value,example )

# TO RENAME FILES FOR PHOTOSHOP
folder <- "C:/Users/Inigo/Documents/Drought_Map/images/sequencia"

file_names <- data.frame(number = as.numeric(gsub("\\D", "", list.files(folder))), file = list.files(folder)) %>% 
  arrange(number) %>% 
  mutate(id = row_number(),
         new_name = paste0("spei_Madrid_",id,".png"))

file.rename(file.path(folder,file_names$file),file.path(folder,file_names$new_name))           
