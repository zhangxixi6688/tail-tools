
# Differential testing, topconfects based


#' Test for differential expression 
#'
#' @param min_reads There must be this many reads for an item to be included in the test, summing over all relevant samples.
#'
#' @export
test_diff_exp <- function(pipeline_dir, design, min_reads=10, samples=NULL, title=NULL, ...) {
    tc <- read_tail_counts(paste0(pipeline_dir, "/expression/genewise/counts.csv"))

    if (is.null(samples))
        samples <- tc$samples$sample

    tc <- tail_counts_subset_samples(tc, samples)

    mat <- tail_counts_get_matrix(tc, "count")
    keep <- rowSums(mat) >= min_reads

    fit <- 
        edgeR::DGEList(
            mat[keep,,drop=FALSE],
            genes=select_(tc$features[keep,,drop=FALSE],~-feature)) %>%
        edgeR::calcNormFactors() %>%
        edgeR::estimateDisp(design) %>%
        edgeR::glmQLFit(design)
    
    result <- topconfects::edger_confects(fit, ...)
    result$pipeline_dir <- pipeline_dir
    result$title <- title

    result
}


test_diff_tail <- function(counts_filename, min_reads=10, ...) {

}



#test_shiftexp <- function(pipeline_dir, subset="", min_reads=10, design, coef1, coef2) {
#    # Use effect_shift_log2 or ... hmm ... thingything
#}


#test_shift_tail <- function(pipeline_dir, subset="", min_reads=10, design, coef1, coef2) {
#    # Use effect_rss
#}




#' @export
test_end_shift <- function(
        pipeline_dir, design, coef1, coef2, min_reads=10, samples=NULL,  
        fdr=0.05, step=0.01,
        antisense=F, colliders=F, non_utr=F,
        title=NULL) {
    assert_that(length(coef1) == 1)
    assert_that(length(coef2) == 1)

    gene_counts_filename <- paste0(pipeline_dir, "/expression/genewise/counts.csv")
    gene_dat <- read_grouped_table(gene_counts_filename)

    counts_filename <- paste0(pipeline_dir, "/expression/peakwise/counts.csv")
    dat <- read_grouped_table(counts_filename)
    
    counts <- as.matrix(dat$Count)
    peak_info <- dplyr::as_data_frame(dat$Annotation)
    peak_info$id <- rownames(counts)

    if (is.null(samples))
        samples <- colnames(counts)

    assert_that(all(samples %in% colnames(counts)))
    assert_that(nrow(design) == length(samples))
    
    for(name in colnames(peak_info))
        if (is.factor(peak_info[[name]]))
            peak_info[[name]] <- as.character(peak_info[[name]])

    # A peak may be sense to one gene and antisense to another.
    #   ( Tail Tools does not consider situations any more complex than this. )
    # Duplicate peaks antisense to a gene so they can be included in both genes
    #   ( Peaks not assigned a sense gene may already be labelled antisense to another gene,
    #     these don't need to be duplicated. )
    if (antisense && colliders && "antisense_parent" %in% colnames(peak_info)) {
        anti <- (peak_info$antisense_parent != "") & 
                (peak_info$relation != "Antisense") &
                (peak_info$antisense_parent != "")
        anti_counts <- counts[anti,,drop=F]
        anti_info <- peak_info[anti,,drop=F]
        
        # Incorporate antisense peaks
        anti_info <- anti_info %>% 
            dplyr::transmute_(
                id =~ paste0(id,"-collider"),
                start =~ start,
                end =~ end,
                strand =~ strand,
                relation =~ "Antisense",
                gene =~ antisense_gene,
                product =~ antisense_product,
                biotype =~ antisense_biotype,
                parent =~ antisense_parent
            )
        rownames(anti_counts) <- anti_info$id
        
        peak_info <- peak_info %>% 
            dplyr::select_(~id,~start,~end,~strand,~relation,~gene,~product,~biotype,~parent)
                
        counts <- rbind(counts, anti_counts)
        peak_info <- dplyr::bind_rows(peak_info, anti_info)
    }


    peak_info$product <- stringr::str_match(peak_info$product, "^[^ ]+ (.*)$")[,2]
    
    # Filter by relation to gene
    keep <- peak_info$parent != ""
    
    if (!antisense)
        keep <- keep & peak_info$relation != "Antisense"
        
    if (!non_utr)
        keep <- keep & peak_info$relation == "3'UTR"
        
    counts <- counts[keep,samples,drop=F]
    peak_info <- peak_info[keep,,drop=F]


    # Minimum read count filter
    keep2 <- rowSums(counts) >= min_reads
    counts <- counts[keep2,,drop=F]
    peak_info <- peak_info[keep2,,drop=F]


    # Order by position
    position <- ifelse(peak_info$strand>0, peak_info$end, peak_info$start)
    strand <- peak_info$strand
    anti <- peak_info$relation == "Antisense"
    strand[anti] <- strand[anti] * -1
    
    ord <- order(strand*position)
    counts <- counts[ord,,drop=F]
    peak_info <- peak_info[ord,,drop=F]


    # Perform test
    fit <- 
        edgeR::DGEList(counts) %>%
        edgeR::calcNormFactors() %>%
        edgeR::estimateDisp(design) %>%
        edgeR::glmQLFit(design)
    
    group_effect <- topconfects::group_effect_shift_log2(design, coef1, coef2)

    result <- topconfects::edger_group_confects(
        fit, peak_info$parent, group_effect, step=step, fdr=fdr)

    result$table <- cbind(result$table, gene_dat$Annotation[result$table$name,,drop=F])

    result$pipeline_dir <- pipeline_dir
    result$title <- title

    result
}


