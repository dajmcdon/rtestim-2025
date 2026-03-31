measles <- read_csv(
  file = "https://raw.githubusercontent.com/CSSEGISandData/measles_data/refs/heads/main/measles_county_all_updates_detailed.csv",
  col_types = "cc_Dcd"
) |>
  filter(!is.na(location_id), nchar(location_id) >= 3) |>
  mutate(
    nc = nchar(location_id)
  ) |>
  rowwise() |>
  mutate(
    fips = case_when(
      nc == 5 ~ location_id,
      .default = paste0(c(rep("0", 5 - nc), location_id), collapse = "")
    )
  ) |>
  ungroup()

measles <- measles |>
  group_by(fips) |>
  summarise(date = max(date), value = sum(value))

plot_measles_bubble <- function(
  x,
  max_size = 15
) {
  border_col <- "darkgray"
  border_size <- 0.1
  back_col <- NA
  theme_layer <- theme_void() +
    theme(
      legend.position = "bottom",
      legend.title.position = "top",
      legend.title = element_text(hjust = .5),
      legend.key.width = unit(1, "cm")
    )
  map_df <- covidcast:::read_geojson_data("county")
  map_df$STATEFP <- as.character(map_df$STATEFP)
  map_df$GEOID <- as.character(map_df$GEOID)
  map_df <- map_df |>
    dplyr::filter(!(.data$COUNTYFP == "000")) |>
    dplyr::mutate(
      is_alaska = .data$STATEFP == "02",
      is_hawaii = .data$STATEFP == "15",
      is_pr = .data$STATEFP == "72",
      is_state = as.numeric(.data$STATEFP) < 57,
    )

  map_df <- left_join(map_df, x, by = join_by(GEOID == fips))
  main_df <- shift_main(map_df)
  hawaii_df <- shift_hawaii(map_df)
  alaska_df <- shift_alaska(map_df)

  geom_args <- list()
  geom_args$color <- border_col
  geom_args$size <- border_size
  geom_args$mapping <- ggplot2::aes(geometry = .data$geometry)
  geom_args$fill <- back_col
  geom_args$data <- main_df
  main_layer <- do.call(ggplot2::geom_sf, geom_args)

  geom_args$data <- hawaii_df
  geom_args$fill <- back_col
  hawaii_layer <- if (nrow(hawaii_df) > 0) {
    do.call(ggplot2::geom_sf, geom_args)
  } else {
    ggplot2::geom_blank()
  }
  geom_args$data <- alaska_df
  geom_args$fill <- back_col
  alaska_layer <- if (nrow(alaska_df) > 0) {
    do.call(ggplot2::geom_sf, geom_args)
  } else {
    ggplot2::geom_blank()
  }
  suppressWarnings({
    main_df$geometry <- sf::st_centroid(main_df$geometry)
    hawaii_df$geometry <- sf::st_centroid(hawaii_df$geometry)
    alaska_df$geometry <- sf::st_centroid(alaska_df$geometry)
  })
  geom_args <- list()
  geom_args$mapping <- ggplot2::aes(
    geometry = .data$geometry,
    size = .data$value,
    color = date
  )
  geom_args$alpha <- 0.5
  geom_args$na.rm <- TRUE
  geom_args$show.legend <- "point"
  bubble_blank_if_all_na <- function(geom_args, df) {
    geom_args$data <- df
    bubble_layer <- ggplot2::geom_blank()
    if (!all(is.na(df$value))) {
      bubble_layer <- do.call(ggplot2::geom_sf, geom_args)
    }
    return(bubble_layer)
  }
  main_bubble_layer <- bubble_blank_if_all_na(geom_args, main_df)
  hawaii_bubble_layer <- bubble_blank_if_all_na(geom_args, hawaii_df)
  alaska_bubble_layer <- bubble_blank_if_all_na(geom_args, alaska_df)
  guide <- ggplot2::guide_legend(
    title = "# of cases",
    direction = "horizontal",
    nrow = 1
  )
  scale_layer1 <- scale_size_binned_area(
    breaks = c(1, 10, 25, 100, 250, 750),
    max_size = max_size,
    guide = guide
  )
  scale_layer2 <- scale_color_date(
    name = "Most recent case",
    low = secondary,
    high = tertiary,
    date_labels = "%m/%y"
  )
  ggplot2::ggplot() +
    main_layer +
    alaska_layer +
    hawaii_layer +
    main_bubble_layer +
    hawaii_bubble_layer +
    alaska_bubble_layer +
    scale_layer1 +
    scale_layer2 +
    theme_layer
}

shift_alaska <- function(map_df) {
  alaska_df <- map_df |> filter(is_alaska)
  alaska_df <- sf::st_transform(alaska_df, covidcast:::alaska_crs)
  alaska_scale <- sf::st_geometry(alaska_df) * 0.35
  alaska_df <- sf::st_set_geometry(alaska_df, alaska_scale)
  alaska_shift <- sf::st_geometry(alaska_df) + c(-1800000, -1600000)
  alaska_df <- sf::st_set_geometry(alaska_df, alaska_shift)
  suppressWarnings({
    sf::st_crs(alaska_df) <- covidcast:::final_crs
  })
  return(alaska_df)
}

shift_hawaii <- function(map_df) {
  hawaii_df <- map_df |> filter(.data$is_hawaii)
  hawaii_df <- sf::st_transform(hawaii_df, covidcast:::hawaii_crs)
  hawaii_shift <- sf::st_geometry(hawaii_df) + c(-1e+06, -2e+06)
  hawaii_df <- sf::st_set_geometry(hawaii_df, hawaii_shift)
  suppressWarnings({
    sf::st_crs(hawaii_df) <- covidcast:::final_crs
  })
  return(hawaii_df)
}

shift_main <- function(map_df) {
  main_df <- map_df |>
    filter(!is_alaska & !is_hawaii & !is_pr)
  if ("is_state" %in% colnames(main_df)) {
    main_df <- main_df |> filter(is_state)
  }
  main_df <- sf::st_transform(main_df, covidcast:::final_crs)
  return(main_df)
}

plt <- plot_measles_bubble(measles)
ggsave("gfx/measles-bubble.svg", width = 9, height = 6)
