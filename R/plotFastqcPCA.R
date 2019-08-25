#' @title Draw a PCA plot for Fast QC modules
#'
#' @description Draw a PCA plot for Fast QC modules across multiple samples
#'
#' @details
#' This carries out PCA on all or a subset of FastQC modules and plots the
#' output using either ggplot or plotly. Clustering of the PCA can be carried
#' out using a heirachial clustering approach. Current modules for PCA are
#' Per_base_sequence_quality, Per_sequence_quality_scores,
#' Per_sequence_GC_content, Per_base_sequence_content, and
#' Sequence_Length_Distribution.

#'
#' @param x Can be a \code{FastqcData}, \code{FastqcDataList} or file paths
#' @param module \code{character} vector containing
#'  the desired FastQC module (eg. c("Per_base_sequence_quality",
#'  "Per_base_sequence_content"))
#' @param usePlotly \code{logical}. Output as ggplot2 (default) or plotly
#' object.
#' @param labels An optional named vector of labels for the file names.
#' All filenames must be present in the names.
#' File extensions are dropped by default
#' @param cluster \code{logical} default \code{FALSE}. If \code{groups} argument
#' is not set fastqc data will be clustered using hierarchical clustering.
#' @param clusterType One of "color" or "hulls". Default is "colors" and will 
#' color points based on cluster/group, "hulls" will draw a polygon around each
#'  cluster.
#' @param groups named \code{list} of predefined sample groups
#' (eg. R1 and R2 or Sequencing Lanes) to cluster by
#' @param ... Used to pass additional attributes to theme() and between methods
#'
#' @return A standard ggplot2 object, or an interactive plotly object
#'
#' @docType methods
#'
#' @importFrom dplyr left_join
#' @importFrom dplyr group_by
#' @importFrom dplyr ungroup
#' @importFrom dplyr slice
#' @importFrom FactoMineR HCPC
#' @importFrom FactoMineR PCA
#' @importFrom grDevices chull
#' @importFrom reshape2 dcast
#' @importFrom stats kmeans
#' @importFrom stats prcomp
#' @import ggplot2
#' @import tibble
#'
#' @examples
#'
#' # Get the files included with the package
#' packageDir <- system.file("extdata", package = "ngsReports")
#' fl <- list.files(packageDir, pattern = "fastqc.zip", full.names = TRUE)
#'
#' # Load the FASTQC data as a FastqcDataList object
#' fdl <- FastqcDataList(fl)
#' plotFastqcPCA(fdl, module = "Per_sequence_quality_scores",
#' usePlotly = FALSE, cluster = TRUE, groups = NULL)
#'
#'
#' @name plotFastqcPCA
#' @rdname plotFastqcPCA-methods
#' @export
setGeneric("plotFastqcPCA", function(
    x, module, usePlotly = FALSE, labels, cluster = FALSE, clusterType, groups = NULL, ...){
    standardGeneric("plotFastqcPCA")
}
)
#' @rdname plotFastqcPCA-methods
#' @export
setMethod("plotFastqcPCA", signature = "ANY", function(
    x, module, usePlotly = FALSE, labels, cluster = FALSE, 
    clusterType = "color", groups = NULL, ...){
    .errNotImp(x)
}
)
#' @rdname plotFastqcPCA-methods
#' @export
setMethod("plotFastqcPCA", signature = "character", function(
    x, module, usePlotly = FALSE, labels, cluster = FALSE, 
    clusterType = "color", groups = NULL, ...){
    x <- FastqcDataList(x)
    if (length(x) == 1) x <- x[[1]]
    plotFastqcPCA(x, module, usePlotly, labels, cluster, 
                  clusterType = "color", groups, ...)
}
)
#' @rdname plotFastqcPCA-methods
#' @export
setMethod("plotFastqcPCA", signature = "FastqcDataList", function(
    x, module, usePlotly = FALSE, labels, cluster = FALSE,
    clusterType = "color", groups = NULL, ...){

    ## Get any arguments for dotArgs that have been set manually
    dotArgs <- list(...)
    allowed <- names(formals(theme))
    keepArgs <- which(names(dotArgs) %in% allowed)
    userTheme <- c()
    if (length(keepArgs) > 0) userTheme <- do.call(theme, dotArgs[keepArgs])

    pFun <- paste0(".generate", module, "PCA")
    args <- list(x = x)

    df <- do.call(pFun, args)

    pca <- PCA(df,scale.unit = TRUE, ncp = 2, graph = FALSE)
    variance <- round(pca$eig[,2][seq_len(2)], 2)

    data <- as.data.frame(pca$ind$coord)

    if (cluster) {
        if (is.null(groups)) {
            ### with factoMineR
            set.seed(1)
            cluster <- HCPC(
                pca, nb.clust = 0, consol = 0, min = 2, max = 10, graph = FALSE
            )

            cluster <- cluster$call$X
            nClust <- max(as.integer(as.character(cluster[["clust"]])))
            cluster <- cluster[c("Dim.1", "Dim.2", "clust")]
            colnames(cluster) <- c("Dim.1", "Dim.2", "Cluster")

            data <- rownames_to_column(cluster, "Filename")

        }
        else{

            groupDF <- lapply(seq_along(groups), function(x){

                data.frame(
                    Filename = groups[[x]],
                    Cluster = names(groups)[x],
                    stringsAsFactors = FALSE
                    )

            })

            groupDF <- bind_rows(groupDF)
            data <- left_join(data, groupDF, by = "Filename")
        }
        
        
        #data <- left_join(clusterDF, scores, by = "Filename")
        data$PCAkey <- data$Filename
        labels <- .makeLabels(data, labels, ...)
        data$Filename <- labels[data$Filename]
        clust <- c()
        data$Cluster <- as.character(data$Cluster)
        ## get convex edges
        
        
        PCA <- ggplot() +
            geom_hline(yintercept = 0, colour = "darkgrey") +
            geom_vline(xintercept = 0, colour = "darkgrey") +
            theme_bw() +
            theme(
                panel.background = element_blank()
            ) +
            labs(
                x = paste0("PC1 (", variance[1], "%)"),
                y = paste0("PC2 (", variance[2], "%)")
            )
        
        if (clusterType == "hulls"){
            
            hulls <- group_by(data, Cluster)
            
            Dim.1 <- c()
            Dim.2 <- c()
            hulls <- slice(hulls, chull(Dim.1, Dim.2))
            hulls <- ungroup(hulls)
            hulls$Cluster <- factor(hulls$Cluster, 
                                    levels = unique(hulls$Cluster))
            
            PCA <- PCA +
                geom_point(
                    data = data,
                    aes_string(x = "Dim.1", y = "Dim.2",group = "Filename"),
                    size = 0.7
                ) +
                geom_polygon(
                    data = hulls,
                    aes_string(x = "Dim.1", y = "Dim.2", fill = "Cluster"),
                    alpha = 0.4
                )
            
        }
        else {
            
            PCA <- PCA +
                geom_point(
                    data = data,
                    aes_string(x = "Dim.1", y = "Dim.2", group = "Filename", 
                               colour = "Cluster"),
                    size = 0.7
                )
            
        }
        
        


        if (!is.null(userTheme)) nPlot <- nPlot + userTheme


        if (usePlotly) {
            PCA <- ggplotly(PCA)

            s <- split(data, data$clust)

            ## Where have k & j been initialised?
            PCA$x$data[2:(nClust + 1)] <- lapply(seq_len(nClust), function(j){

                names <- s[[j]]$Filename
                names <- paste(names, collapse = "<br>")
                PCA$x$data[[j + 1]]$text <- names
                ## add key
                PCA$x$data[[j + 1]]

            })
        }
    }
    else{
        data <- rownames_to_column(data, "Filename")
        
        PCA <- ggplot() +
            geom_hline(yintercept = 0, colour = "darkgrey") +
            geom_vline(xintercept = 0, colour = "darkgrey") +
            theme_bw() +
            theme(
                panel.background = element_blank()
            ) +
            labs(
                x = paste0("PC1 (", variance[1], "%)"),
                y = paste0("PC2 (", variance[2], "%)")
            ) +
            geom_point(
                data = data,
                aes_string(x = "Dim.1", y = "Dim.2", group = "Filename")
            ) 


        if (!is.null(userTheme)) nPlot <- nPlot + userTheme


        if (usePlotly) {
            PCA <- ggplotly(PCA)
        }}

    PCA
}

)


.generatePer_base_sequence_qualityPCA <- function(x){

    df <- getModule(x, "Per_base_sequence_quality")
    df$Start <- as.integer(gsub("([0-9]*)-[0-9]*", "\\1", df$Base))

    ## Adjust the data for files with varying read lengths
    ## This will fill NA values with the previous values
    df <- lapply(
        split(df, f = df$Filename),
        function(y){
            Longest_sequence <-
                gsub(".*-([0-9]*)", "\\1", as.character(y$Base))
            Longest_sequence <- max(as.integer(Longest_sequence))
            dfFill <- data.frame(Start = seq_len(Longest_sequence))
            y <- dplyr::right_join(y, dfFill, by = "Start")
            na.locf(y)
        }
    )

    df <- dplyr::bind_rows(df)[c("Filename", "Start", "Mean")]
    df <- tidyr::spread(df, "Start", "Mean", fill = 0)
    df <- as.data.frame(df)
    df <- column_to_rownames(df, "Filename")
    df
}

.generatePer_sequence_quality_scoresPCA <- function(x){

    df <- getModule(x, "Per_sequence_quality_scores")
    df <- tidyr::spread(df, "Quality", "Count", fill = 0)
    df <- as.data.frame(df)
    df <- column_to_rownames(df, "Filename")
    df
}


.generatePer_sequence_GC_contentPCA <- function(x){

    df <- getModule(x, "Per_sequence_GC_content")
    df <- tidyr::spread(df, "GC_Content", "Count", fill = 0)
    df <- as.data.frame(df)
    df <- column_to_rownames(df, "Filename")
    df
}


.generatePer_base_sequence_contentPCA <- function(x){

    df <- getModule(x, "Per_base_sequence_content")
    df$Start <- as.integer(gsub("([0-9]*)-[0-9]*", "\\1", df$Base))

    ## Adjust the data for files with varying read lengths
    ## This will fill NA values with the previous values
    df <- lapply(split(df, f = df$Filename), function(y){
        Longest_sequence <-
            gsub(".*-([0-9]*)", "\\1", as.character(y$Base))
        Longest_sequence <- max(as.integer(Longest_sequence))
        dfFill <- data.frame(Start = seq_len(Longest_sequence))
        y <- dplyr::right_join(y, dfFill, by = "Start")
        na.locf(y)
    })
    df <- dplyr::bind_rows(df)[c("Filename", "Start", "G", "A", "T", "C")]

    perBaseList <- lapply(c("G", "A", "T", "C"), function(y){
        spreadDF <- df[c("Filename", "Start", y)]

        spreadDF <- tidyr::spread(spreadDF, "Start", y, fill = 0)
        
        colnames(spreadDF)[2:ncol(spreadDF)] <- 
            paste0(colnames(spreadDF)[2:ncol(spreadDF)], ".", y)
        spreadDF
    })
    
    ## i and j are functional variables spawned from perBaseList in order to 
    ## join each base by filename
    df <- Reduce(function(i,j) dplyr::left_join(i,j,by="Filename"), perBaseList)
    df <- column_to_rownames(df, "Filename")
}

.generateSequence_Length_DistributionPCA <- function(x){

    df <- getModule(x, "Sequence_Length_Distribution")
    df <- lapply(split(df, f = df$Filename), function(y){
        Longest_sequence <-
            gsub(".*-([0-9]*)", "\\1", as.character(y$Length))
        Longest_sequence <- max(as.integer(Longest_sequence))
        dfFill <- data.frame(Lower = seq_len(Longest_sequence))
        y <- dplyr::right_join(y, dfFill, by = "Lower")
        na.locf(y)
    })
    df <- dplyr::bind_rows(df)[c("Filename", "Lower", "Count")]
    df <- tidyr::spread(df, "Lower", "Count", fill = 0)
    df <- column_to_rownames(df, "Filename")
    df
}