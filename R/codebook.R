##########################################
#      Packages installieren & laden     #
##########################################

# Pakete definieren und installieren, falls notwendig
required_packages <- c(
  "ggplot2", "zoo", "plm", "dplyr",
  "modelsummary", "knitr", "kableExtra"
)

# Fehlende Pakete installieren
new_packages <- required_packages[!sapply(required_packages,
                                          requireNamespace,
                                          quietly = TRUE)]
if (length(new_packages)) install.packages(new_packages)

# Alle Pakete laden
invisible(lapply(required_packages, library, character.only = TRUE))

##########################################
#         Funktionen definieren          #
##########################################

# Funktion zur Beschreibung der Variablen
describe_variables <- function(data, variables) {
  options(scipen = 999) # Deaktiviert wissenschaftliche Notation
  described_variables <- data.frame()
  for (var_name in variables) {
    variable <- data[[var_name]]
    if (is.numeric(variable)) {
      summary_stats <- data.frame(
        Variable = var_name,
        Min = round(min(variable, na.rm = TRUE), 2),
        Max = round(max(variable, na.rm = TRUE), 2),
        Mean = round(mean(variable, na.rm = TRUE), 2),
        Median = round(median(variable, na.rm = TRUE), 2),
        SD = round(sd(variable, na.rm = TRUE), 2),
        N = sum(!is.na(variable))
      )
      described_variables <- rbind(described_variables, summary_stats)
    } else {
      warning(paste("Variable", var_name,
                    "ist nicht numerisch und wurde übersprungen."))
    }
  }
  return(described_variables)
}

# Funktion für deskriptive Visualisierung pro Land
plot_country_data <- function(data, country_name) {
  # Mapping für deutsche Ländernamen in den Plots
  country_map <- c("Spain" = "Spanien", "Poland" = "Polen",
                   "Sweden" = "Schweden", "Germany" = "Deutschland",
                   "United Kingdom" = "Großbritannien")
  # Falls das Land in der Map existiert, nutze den deutschen Namen
  display_name <- ifelse(country_name %in% names(country_map),
                         country_map[[country_name]], country_name)
  # Prüfe, ob die Variablen existieren
  required_vars <- c("ICT_INVEST_SHARE_GDP",
                     "UNEMPLOYMENT_RATE_PERCENT",
                     "YEAR_OF_OBSERVATION", "SUBJECT")
  missing_vars <- setdiff(required_vars, colnames(data))
  if (length(missing_vars) > 0) {
    stop(paste("Fehlende Spalten im Datensatz:",
               paste(missing_vars, collapse = ", ")))
  }
  # Daten filtern
  filtered_data <- data %>%
    filter(REFERENCE_AREA == country_name) %>%
    mutate(SUBJECT = recode(SUBJECT,
                            "Tertiary" =
                              "hohes Bildungsniveau",
                            "Upper secondary, non-tertiary" =
                              "mittleres Bildungsniveau",
                            "Below upper secondary" =
                              "niedriges Bildungsniveau")) %>%
    mutate(SUBJECT = factor(SUBJECT, levels = c("niedriges Bildungsniveau",
                                                "mittleres Bildungsniveau",
                                                "hohes Bildungsniveau")))
  # Prüfen, ob nach dem Filtern noch Daten vorhanden sind
  if (nrow(filtered_data) == 0) {
    stop(paste("Keine Daten gefunden für", country_name,
               "in REFERENCE_AREA. Verfügbare Werte:",
               paste(unique(data$REFERENCE_AREA), collapse = ", ")))
  }
  # Skaliere die Werte nur, wenn sie existieren
  max_invest <- max(filtered_data$ICT_INVEST_SHARE_GDP, na.rm = TRUE)
  max_unemp <- max(filtered_data$UNEMPLOYMENT_RATE_PERCENT, na.rm = TRUE)
  ggplot(filtered_data, aes(x = YEAR_OF_OBSERVATION)) +
    geom_line(aes(y = ICT_INVEST_SHARE_GDP,
                  color = "ICT-Investitionen (BIP-Anteil)"), size = 1) +
    geom_line(aes(y = UNEMPLOYMENT_RATE_PERCENT / max_unemp * max_invest,
                  color = "Arbeitslosenquote"),
              size = 1,
              linetype = "dashed") +
    facet_wrap(~SUBJECT, scales = "free_y") +
    labs(
      title = paste("ICT-Investitionen & Arbeitslosenquote in",
                    display_name),
      x = "Jahr", y = "ICT-Investitionen (BIP-Anteil)",
      color = "Indikator"
    ) +
    theme_minimal() +
    scale_x_continuous(
      breaks = seq(min(filtered_data$YEAR_OF_OBSERVATION,
                       na.rm = TRUE),
                   max(filtered_data$YEAR_OF_OBSERVATION,
                       na.rm = TRUE), 5)
    ) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1)) +
    scale_y_continuous(sec.axis = sec_axis(~ . / max_invest * max_unemp,
                                           name = "Arbeitslosenquote (%)"))
}

##########################################
#           Globale Variablen            #
##########################################

# Liste aller Länder für die Analyse
selected_countries <- c(
  "Australia", "Austria", "Belgium", "Bulgaria", "Brazil",
  "Canada", "Croatia", "Czechia", "Denmark", "Estonia",
  "Finland", "France", "Germany", "Greece", "Hungary",
  "Iceland", "Italy", "Ireland","Latvia", "Lithuania",
  "Luxembourg", "Netherlands", "New Zealand", "Norway",
  "Poland", "Portugal", "Romania", "Spain", "Sweden",
  "Switzerland", "Türkiye", "Slovak Republic", "Slovenia",
  "United Kingdom","United States"
)

# Liste aller Variablen für die Analyse
variables <- c(
  "UNEMPLOYMENT_RATE_PERCENT", "ICT_INVEST_SHARE_GDP",
  "GDP_PER_CAPITA", "PERCENT_EMPLOYEES_TUD"
)

#############################################
# Bereinigung und Zusammenführung der Daten #
#############################################

# OECD-Datensatz zu Arbeitslosenquoten
data_unemp <- read.table(
  "data/OECD_unemployment_rates_by_education_level_annual_2000-2022.csv",
  header = TRUE, sep = ",", dec = ".", fileEncoding = "UTF-8"
) %>%
  # Filtern nach ausgewählten Ländern und Zeiträumen
  filter(
    Country %in% selected_countries,
    TIME_PERIOD >= 2005 & TIME_PERIOD <= 2022
  ) %>%
  # Wohlfahrtsstaat-Kategorisierung und Typkonvertierung
  mutate(
    WELFARE_STATE = case_when(
      Country %in% c("Denmark", "Sweden",
                     "Norway", "Finland", "Iceland") ~ "Nordic",
      Country %in% c("Germany", "France", "Austria",
                     "Belgium", "Netherlands",
                     "Luxembourg", "Switzerland") ~ "Central European",
      Country %in% c("United States", "United Kingdom",
                     "Canada", "Australia", "New Zealand",
                     "Ireland") ~ "Anglo-Saxon",
      Country %in% c("Italy", "Spain", "Portugal",
                     "Greece") ~ "Southern European",
      Country %in% c("Poland", "Czechia", "Hungary",
                     "Slovak Republic", "Slovenia",
                     "Estonia", "Latvia", "Lithuania",
                     "Romania", "Bulgaria") ~ "Post-socialist",
      TRUE ~ "Other"  # Falls Länder fehlen, werden sie kategorisiert
    ),
    WELFARE_STATE = as.factor(WELFARE_STATE),
    REFERENCE_AREA = as.character(Country),
    SUBJECT = as.character(Subject),
    YEAR_OF_OBSERVATION = as.integer(TIME_PERIOD),
    UNEMPLOYMENT_RATE_PERCENT = OBS_VALUE
  ) %>%
  # Entferne nicht benötigte Spalten und ordne sie neu
  select(REFERENCE_AREA, WELFARE_STATE, YEAR_OF_OBSERVATION,
         SUBJECT, UNEMPLOYMENT_RATE_PERCENT)

# OECD-Datensatz zu ICT-Investments
data_ictinvest <- read.table(
  "data/OECD_ICT_investment_share_of_gdp_2000-2022.csv",
  header = TRUE, sep = ",", dec = ".", fileEncoding = "UTF-8"
) %>%
  filter(
    Country %in% selected_countries,
    Year >= 2005 & Year <= 2022,
    Unit.of.measure == "Share of GDP",
    Breakdown == "Total ICT investment"
  ) %>%
  mutate(
    REFERENCE_AREA = as.character(Country),
    YEAR_OF_OBSERVATION = as.integer(Year),
    ICT_INVEST_SHARE_GDP = Value
  ) %>%
  select(REFERENCE_AREA, YEAR_OF_OBSERVATION, ICT_INVEST_SHARE_GDP)

# OECD-Datensatz zu GDPs
data_gdp <- read.table(
  "data/OECD_gdp_2000-2023.csv",
  header = TRUE, sep = ",", dec = ".", fileEncoding = "UTF-8"
) %>%
  filter(
    Reference.area %in% selected_countries,
    TIME_PERIOD >= 2005 & TIME_PERIOD <= 2022
  ) %>%
  mutate(
    REFERENCE_AREA = as.character(Reference.area),
    YEAR_OF_OBSERVATION = as.integer(TIME_PERIOD),
    GDP_PER_CAPITA = OBS_VALUE
  ) %>%
  select(REFERENCE_AREA, YEAR_OF_OBSERVATION, GDP_PER_CAPITA)

# OECD-Datensatz zu Trade Union Density
data_tud <- read.table(
  "data/OECD_trade_union_density.csv",
  header = TRUE, sep = ",", dec = ".", fileEncoding = "UTF-8"
) %>%
  filter(
    Reference.area %in% selected_countries,
    TIME_PERIOD >= 2005 & TIME_PERIOD <= 2022
  ) %>%
  mutate(
    REFERENCE_AREA = as.character(Reference.area),
    YEAR_OF_OBSERVATION = as.integer(TIME_PERIOD),
    PERCENT_EMPLOYEES_TUD = OBS_VALUE
  ) %>%
  select(REFERENCE_AREA, YEAR_OF_OBSERVATION, PERCENT_EMPLOYEES_TUD)

##################################
# Zusammenführung der Datensätze #
##################################

# Einen Datensatz mit allen Daten erstellen
merged_data <- data_ictinvest %>%
  left_join(data_unemp, by = c("REFERENCE_AREA", "YEAR_OF_OBSERVATION")) %>%
  left_join(data_gdp, by = c("REFERENCE_AREA", "YEAR_OF_OBSERVATION")) %>%
  left_join(data_tud, by = c("REFERENCE_AREA", "YEAR_OF_OBSERVATION")) %>%
  group_by(REFERENCE_AREA) %>%
  arrange(YEAR_OF_OBSERVATION) %>%  # Sortierung für Interpolation
  mutate(PERCENT_EMPLOYEES_TUD = na.approx(
                                           as.numeric(PERCENT_EMPLOYEES_TUD),
                                           na.rm = FALSE, rule = 2)) %>%
  ungroup() %>%  # Entgruppierung wegen Interpolation
  mutate(
    SUBJECT = recode(
                     SUBJECT,
                     "Below upper secondary" =
                       "niedriges Bildungsniveau",
                     "Upper secondary, non-tertiary" =
                       "mittleres Bildungsniveau",
                     "Tertiary" =
                       "hohes Bildungsniveau"),
    # Dummy-Variable für Jahresfixeffekte
    YEAR_FACTOR = relevel(factor(YEAR_OF_OBSERVATION), ref = "2005")
  )

##########################################
#         Übersicht über Variablen       #
##########################################

# Beschreibung der Variablen
described_variables <- describe_variables(merged_data, variables)

# Ergebnisse anzeigen und speichern
print(described_variables)
writeLines(
  kable(described_variables,
    format = "latex",
    booktabs = TRUE,
    caption = "Zusammenfassung der Variablen"
  ) %>%
    kable_styling(latex_options = c("hold_position")),
  "../TeX/assets/variables.tex"
)

##########################################
#       Länderspezifische Analyse        #
##########################################

# Spanien als Südeuropäischer Wohlfahrtsstaat
plot_spain    <- plot_country_data(merged_data, "Spain")
print(plot_spain)
ggsave("../TeX/assets/plot_spain.png",
       plot = plot_spain, width = 12, height = 3)

# Polen als postsozialistischer Wohlfahrtsstaat
plot_poland   <- plot_country_data(merged_data, "Poland")
print(plot_poland)
ggsave("../TeX/assets/plot_poland.png",
       plot = plot_poland, width = 12, height = 3)

# Schweden als nordischer Wohlfahrtsstaat
plot_sweden   <- plot_country_data(merged_data, "Sweden")
print(plot_sweden)
ggsave("../TeX/assets/plot_sweden.png",
       plot = plot_sweden, width = 12, height = 3)

# Deutschland als konservativer Wohlfahrtsstaat
plot_germany  <- plot_country_data(merged_data, "Germany")
print(plot_germany)
ggsave("../TeX/assets/plot_germany.png",
       plot = plot_germany, width = 12, height = 3)

# Großbritannien als angelsächsischer Wohlfahrtsstaat
plot_uk       <- plot_country_data(merged_data, "United Kingdom")
print(plot_uk)
ggsave("../TeX/assets/plot_uk.png",
       plot = plot_uk, width = 12, height = 3)

##########################################
#   Daten nach Bildungsgruppen filtern   #
##########################################

filter_data_low     <- subset(merged_data, SUBJECT ==
                                "niedriges Bildungsniveau")
filter_data_medium  <- subset(merged_data, SUBJECT ==
                                "mittleres Bildungsniveau")
filter_data_high    <- subset(merged_data, SUBJECT ==
                                "hohes Bildungsniveau")

#################################
# Modelle mit Kontrollvariablen #
#################################

# Fixed Effects Modelle (mit Kontrollvariablen)
model_low_fe_control    <- plm(
  UNEMPLOYMENT_RATE_PERCENT ~ ICT_INVEST_SHARE_GDP +
    GDP_PER_CAPITA +
    PERCENT_EMPLOYEES_TUD,
  data = filter_data_low,
  model = "within",
  index = c("REFERENCE_AREA", "YEAR_OF_OBSERVATION")
)

model_medium_fe_control <- plm(
  UNEMPLOYMENT_RATE_PERCENT ~ ICT_INVEST_SHARE_GDP +
    GDP_PER_CAPITA +
    PERCENT_EMPLOYEES_TUD,
  data = filter_data_medium,
  model = "within",
  index = c("REFERENCE_AREA", "YEAR_OF_OBSERVATION")
)

model_high_fe_control   <- plm(
  UNEMPLOYMENT_RATE_PERCENT ~ ICT_INVEST_SHARE_GDP +
    GDP_PER_CAPITA +
    PERCENT_EMPLOYEES_TUD,
  data = filter_data_high,
  model = "within",
  index = c("REFERENCE_AREA", "YEAR_OF_OBSERVATION")
)

############################################################
# Fixed Effects Modelle mit Interaktionen und Jahresfaktor #
############################################################

model_low_fe_interaction    <- plm(
  UNEMPLOYMENT_RATE_PERCENT ~ ICT_INVEST_SHARE_GDP * WELFARE_STATE +
    YEAR_FACTOR +
    GDP_PER_CAPITA +
    PERCENT_EMPLOYEES_TUD,
  data = filter_data_low, model = "within",
  index = c("REFERENCE_AREA")
)

model_medium_fe_interaction <- plm(
  UNEMPLOYMENT_RATE_PERCENT ~ ICT_INVEST_SHARE_GDP * WELFARE_STATE +
    YEAR_FACTOR +
    GDP_PER_CAPITA +
    PERCENT_EMPLOYEES_TUD,
  data = filter_data_medium, model = "within",
  index = c("REFERENCE_AREA")
)

model_high_fe_interaction   <- plm(
  UNEMPLOYMENT_RATE_PERCENT ~ ICT_INVEST_SHARE_GDP * WELFARE_STATE +
    YEAR_FACTOR +
    GDP_PER_CAPITA +
    PERCENT_EMPLOYEES_TUD,
  data = filter_data_high, model = "within",
  index = c("REFERENCE_AREA")
)

########################################
# Übersicht der Modelle und Ergebnisse #
########################################

# Liste für Kontrollmodelle
control_models      <- list(
  "niedriges\nBildungsniv.\n(Kontrolle)" = model_low_fe_control,
  "mittleres\nBildungsniv.\n(Kontrolle)" = model_medium_fe_control,
  "hohes\nBildungsniv.\n(Kontrolle)" = model_high_fe_control
)

# Liste für Interaktionsmodelle
interaction_models  <- list(
  "niedriges\nBildungsniv.\n(Interaktion)" =
    model_low_fe_interaction,
  "mittleres\nBildungsniv.\n(Interaktion)" =
    model_medium_fe_interaction,
  "hohes\nBildungsniv.\n(Interaktion)" =
    model_high_fe_interaction
)

# Ergebnisse anzeigen und speichern
msummary(control_models, stars = TRUE)
msummary(control_models, stars = TRUE,
         output = "../TeX/assets/models_control.tex")
msummary(interaction_models, stars = TRUE)
msummary(interaction_models, stars = TRUE,
         output = "../TeX/assets/models_interaction.tex")
