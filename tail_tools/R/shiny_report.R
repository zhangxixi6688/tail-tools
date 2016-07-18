
#'
#' Shiny report based on pipeline output
#'
#' @param path Directory containing pipeline output.
#'
#' @param species Species for tail heatmap. Currently supports Human ("Hs"), Saccharomyces cerevisiae ("Sc"), Caenorhabditis elegans ("Ce"), Mus musculus ("Mm")
#'
#' @export
shiny_tailtools_report <- function(path, species=NULL) {
    dat <- read.grouped.table(paste0(path,"/expression/genewise/counts.csv"))

    varistran_app <- shiny_report(
        counts=dat$Count,
        feature_labels=dat$Annotation$gene
        )
    
    heatmap_app <- shiny_patseq_heatmap(dat, species=species)
    
    panels <- c(
        list("Varistran"),
        varistran_app$component_panels, 
        list(
            "Tail tools",
            tabPanel("Tail heatmap", heatmap_app$component_ui)
        )
    )
    
    server <- function(env) {
        varistran_app$component_server(env)
        heatmap_app$component_server(env)
    }
    
    composable_shiny_panels_app(panels, server)
}
