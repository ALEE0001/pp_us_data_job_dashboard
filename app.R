library(tidyverse)
library(skimr)
library(kaggler)
library(gtrendsR)
library(blsR)
library(countrycode)
library(plotly)
library(geojsonio)
library(rgdal)
library(broom)
library(rgeos)
library(RColorBrewer)
library(shiny)
library(shinydashboard)
library(shinyWidgets)
library(shinyjs)
library(shinycssloaders)

# Summary: Overview dashboard of data career in United States


# Data----

# AI/ML/Data Science Salary Data 
# https://ai-jobs.net/salaries/download/

# Authenticate to Kaggle API 
# This is Hidden in Github. Please Generate your own for reproducibility.
kaggler::kgl_auth(creds_file = "kaggle.json")

# Download prepped data from Kaggle
# https://www.kaggle.com/datasets/cedricaubin/ai-ml-salaries
df_salary <- kgl_datasets_download(
  owner_dataset = "cedricaubin/ai-ml-salaries",
  fileName = "salaries.csv",
  datasetVersionNumber = 2)

df_salary <-
  df_salary %>% 
  select(year = work_year,
         job_title,
         employment_type,
         experience_level,
         usd_salary = salary_in_usd,
         remote_ratio,
         employee_residence,
         company_location,
         company_size) %>%
    filter(company_location == "US")



# Goggle Trends Data
# https://support.google.com/trends/answer/4365533?hl=en


f_get_trend_data <- function() {
  
  env_get_trend_data <- environment()
  
  trend_datasets <- 
    c("df_interest_over_time", 
      # "df_interest_by_country", 
      "df_interest_by_region",
      "df_interest_by_dma", 
      "df_interest_by_city", 
      "df_related_topics", 
      "df_related_queries")
  
  lapply(trend_datasets, function(x) {if(exists(x)){rm(list = x, envir = env_get_trend_data)}})
  
  topic_keywords <- c("Data Engineering",
                      "Data Analytics", 
                      "Data Science", 
                      "Artificial Intelligence", 
                      "Machine Learning",
                      "Deep Learning")

  for(i in topic_keywords) {
    
    # Download US Search Trend Data from Google Trends API
    l_temp <- gtrends(keyword = i, geo = "US", time = "all")
    
    for(i in trend_datasets){
      
      df_interest_over_time_temp <- l_temp$interest_over_time
      # df_interest_by_country_temp <- l_temp$interest_by_country
      df_interest_by_region_temp <- l_temp$interest_by_region
      df_interest_by_dma_temp <- l_temp$interest_by_dma
      df_interest_by_city_temp <- l_temp$interest_by_city
      df_related_topics_temp <- l_temp$related_topics
      df_related_queries_temp <- l_temp$related_queries
      
      ifelse(exists(i),
             assign(i, eval(as.symbol(i)) %>% bind_rows(eval(as.symbol(paste0(i, "_temp"))))),
             assign(i, eval(as.symbol(paste0(i, "_temp")))))
    }
    
    # Pause 2 seconds after each iteration so google doesn't block me
    Sys.sleep(2)
  }
  
  return(
    list(
      df_interest_over_time = df_interest_over_time, 
      # df_interest_by_country = df_interest_by_country,
      df_interest_by_region = df_interest_by_region,
      df_interest_by_dma = df_interest_by_dma,
      df_interest_by_city = df_interest_by_city,
      df_related_topics = df_related_topics,
      df_related_queries = df_related_queries
      )
    )
}

# l_df_trend <- f_get_trend_data()
# l_df_trend %>% write_rds(file = "data/l_df_trend.rds")
l_df_trend <- read_rds("data/l_df_trend.rds")




# labs(x=NULL,
#      y="Popularity",
#      title = "Google Search Trends",
#      subtitle = "PlaceHolder",
#      caption  = "NOTE: PlaceHolder") +
#   theme(plot.caption = element_text(hjust = 0, face= "italic"),
#         plot.title.position = "plot", 
#         plot.caption.position =  "plot") +





# Define UI
ui <- dashboardPage(
    
  # Application title
  # dashboardHeader(title = div("US Data Career",
  #                             class = "page-title"),
    
    dashboardHeader(title = "US Data Career"),
                  # tags$li(
                  #     div(
                  #         img(src = "logo.png",
                  #             title = "Logo",
                  #             height = "67px"),
                  #         style = "margin-right: 10px;"
                  #     ),
                      # class = "dropdown",
                      # tags$style(".main-header {max-height: 70px}"),
                      # tags$style(".main-header .logo {height: 70px}")
                  # )
  # ),
                  


  dashboardSidebar(
      # includeCSS(path = "www/general.css"),
      useShinyjs(),
      
      sidebarMenu(
          
          pickerInput(
              inputId = "filterkeyword",
              label = "Keyword",
              choices = l_df_trend$df_interest_by_region$keyword %>% unique() %>% sort(),
              multiple = TRUE,
              options = pickerOptions(
                  "actionsBox" = TRUE,
                  "liveSearch" = TRUE,
                  "size" = 10,
                  "noneSelectedText" = "All"
              )
          ),
          
          
          pickerInput(
            inputId = "filterstate",
            label = "State",
            choices = l_df_trend$df_interest_by_region$location %>% unique() %>% sort(),
            multiple = TRUE,
            options = pickerOptions(
              "actionsBox" = TRUE,
              "liveSearch" = TRUE,
              "size" = 10,
              "noneSelectedText" = "All"
              )
            )
          )
      ),



      dashboardBody(
          
          div("Google Search Trends",
                         class = "title_band"),
                
          plotlyOutput("trend"),
          plotOutput("map_region"),
          verbatimTextOutput("test"),
          verbatimTextOutput("test2")
      )
         
 )


# Define server logic required to draw a histogram
server <- function(input, output) {
    
    
    output$test <- renderText(input$filterstate)
    output$test2 <- renderText(length(input$filterstate))
    
    userfilter <- function(x) {
        x %>% filter(if(length(input$filterkeyword) != 0) {keyword %in% input$filterkeyword} else {TRUE})
    }

    df_salary %>% 
        filter(company_location == "US") %>%
        group_by(year, job_title) %>%
        summarise(median_usd_salary = median(usd_salary, na.rm = TRUE)) %>%
        ggplot(aes(x = year, y = median_usd_salary)) +
        geom_bar(stat = "identity") + 
        facet_wrap(~ job_title) +
        theme_bw()
    
    l_df_trend$df_interest_over_time <- 
        l_df_trend$df_interest_over_time %>%
        rename(Date = date, Popularity = hits)
    
    plt_trend <- reactive(
        l_df_trend$df_interest_over_time %>% 
        userfilter() %>%
        ggplot(aes(x = Date, y = Popularity, color = keyword)) +
        # geom_smooth(method = "lm", formula = y ~ poly(x, 3), se = FALSE) +
        geom_line(linewidth = 1.3) +
        geom_point(data = l_df_trend$df_interest_over_time %>% 
                       userfilter() %>%
                       filter(Date == max(Date))) +
        theme_bw() +
        scale_color_brewer(palette = "RdBu", direction = 1, type = "div", name = "") +
        xlab("") +
        ylab("Popularity") 
    )
    
    # ggplotly(plt_trend) %>%
    #     layout(title = list(text = paste0('Google Search Trends',
    #                                       '<br>',
    #                                       '<sup>',
    #                                       'Subtitle PlaceHolder',
    #                                       '</sup>')))
    
    output$trend <- renderPlotly({
      ggplotly(plt_trend()) 
        # %>% layout(legend = list(orientation = "h", x = 0.5, y = -0.3))
    })
    
    
    df_hex_lon_lat <- read_csv("data/hex_lon_lat.csv")
    df_hex_centers <- read_csv("data/hex_centers.csv")
    
    # display.brewer.all(colorblindFriendly = TRUE)
    
    df_region <- 
        df_hex_lon_lat %>% 
        left_join(l_df_trend$df_interest_by_region, by = c("state" = "location")) %>%
        rename(Popularity = hits)
     
    plt_map_region <- reactive(      
        df_region %>%
        userfilter() %>%
        group_by(long, lat, state) %>% 
        mutate(Popularity = mean(Popularity, na.rm = TRUE)) %>%
        ungroup() %>%
        ggplot(aes(x = long, y = lat, group = state)) +
            geom_polygon(aes(fill = Popularity), color = "white") +
            scale_fill_distiller(palette = "Blues", type = "seq", direction = 1) +
            geom_text(data = df_hex_centers, aes(x = long, y = lat, label = state), col = "white") +
            theme_void() +
            coord_map()
        )
         
    output$map_region <- renderPlot({
        plt_map_region()
    })
    
    
    
    
}

# Run the application 
shinyApp(ui = ui, server = server)