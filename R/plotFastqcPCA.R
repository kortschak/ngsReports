#' @title Draw a PCA plot for Fast QC modules
#'
#' @description Draw a PCA plot for Fast QC modules across multiple samples
#'
#' @details
#' This carries out PCA on all or a subset of FastQC modules and plots the
#' output using either ggplot or plotly. Clustering of the PCA can be carried
#' out using a k-means approach.
#'
#'
#' @param x Can be a \code{FastqcData}, \code{FastqcDataList} or file paths
#' @param module \code{character} vector containing 
#'  the desired FastQC module (eg. c("Per_base_sequence_quality","Per_base_sequence_content"))
#' @param usePlotly \code{logical}. Output as ggplot2 (default) or plotly
#' object.
#' @param labels An optional named vector of labels for the file names.
#' All filenames must be present in the names.
#' File extensions are dropped by default
#' @param cluster \code{logical} default \code{FALSE}. If \code{groups} argument is not set
#' fastqc data will be clustered using hierarchical clustering. 
#' @param groups named \code{list} of predefined sample groups (eg. R1 and R2 or Sequencing Lanes)
#' to cluster by
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
#'
#' @name plotFastqcPCA
#' @rdname plotFastqcPCA-methods
#' @export
setGeneric("plotFastqcPCA", function(
    x, module, usePlotly = FALSE, labels, cluster = FALSE, groups = NULL, ...){
    standardGeneric("plotFastqcPCA")
}
)
#' @rdname plotFastqcPCA-methods
#' @export
setMethod("plotFastqcPCA", signature = "ANY", function(
    x, module, usePlotly = FALSE, labels, cluster = FALSE, groups = NULL, ...){
    .errNotImp(x)
}
)
#' @rdname plotFastqcPCA-methods
#' @export
setMethod("plotFastqcPCA", signature = "character", function(
    x, module, usePlotly = FALSE, labels, cluster = FALSE, groups = NULL, ...){
    x <- FastqcDataList(x)
    if (length(x) == 1) x <- x[[1]]
    plotFastqcPCA(x, module, usePlotly, labels, cluster, groups, ...)
}
)
#' @rdname plotFastqcPCA-methods
#' @export
setMethod("plotFastqcPCA", signature = "FastqcDataList", function(
    x, module, usePlotly = FALSE, labels, cluster = FALSE, groups = NULL, ...){
    
    # if(modules == "all") modules <- c("Per_base_sequence_quality", "Per_tile_sequence_quality", 
    #                                    "Per_sequence_quality_scores", "Per_base_sequence_content", 
    #                                    "Per_sequence_GC_content", "Per_base_N_content", 
    #                                    "Sequence_Length_Distribution", "Sequence_Duplication_Levels", 
    #                                    "Overrepresented_sequences", "Adapter_Content", "Kmer_Content", 
    #                                    "Total_Deduplicated_Percentage")
    
    
    ## Get any arguments for dotArgs that have been set manually
    dotArgs <- list(...)
    allowed <- names(formals(theme))
    keepArgs <- which(names(dotArgs) %in% allowed)
    userTheme <- c()
    if (length(keepArgs) > 0) userTheme <- do.call(theme, dotArgs[keepArgs])
    
    pFun <- paste0(".generate", module, "PCA")
    args <- list(
        x = x)
    
    df <- do.call(pFun, args)
    
    pca <- PCA(df,scale.unit=TRUE, ncp=2, graph = FALSE)
    
    variance <- round(pca$eig[,2][1:2], 2)
    
    data <- as.data.frame(pca$ind$coord)
    data <- rownames_to_column(data, "Filename")
    
    #pca <- prcomp(df, scale. = TRUE)
    #variance <- summary(pca)$importance[2,]
    #scores <- as.data.frame(pca$x) 
    
    
    
    if(cluster) {
        
        
        if(is.null(groups)){
            
            #dis <- scores[1:2]
            # Distance <- dist(dis,  method = "euclidean")
            
            
            #https://www.statmethods.net/advstats/cluster.html
            
            
            #k <- Mclust(dis)$G
            #set.seed(1)
            # k means
            
            #kM <- kmeans(scores, centers = k, iter.max=500, algorithm = "MacQueen")
            #kM <- kM$cluster 
            #clust <- hclust(Distance, method = "ward.D2")
            # kM <- cutree(clust, k = k)
            
            
            
            ### with factoMineR
            set.seed(1)
            cluster <- HCPC(pca, nb.clust=0, consol = 0, min=2, max=10, graph = FALSE)
            
            cluster <- cluster$call$X
            k <- max(as.integer(as.character(cluster[["clust"]])))
            cluster <- cluster[c("Dim.1", "Dim.2", "clust")]
            
            # splitClus <- split(names(kM), kM)
            # 
            # clusterDF <- lapply(1:length(splitClus), function(x){
            #     
            #     data.frame(Filename = splitClus[[x]], cluster = as.character(x), stringsAsFactors = FALSE)
            #     
            #     
            # }) 
            # 
            
            # clusterDF <- bind_rows(clusterDF) 
            data <- rownames_to_column(cluster, "Filename")
            
        }
        else{

            groupDF <- lapply(1:length(groups), function(x){

                data.frame(Filename = groups[[x]], clust = names(groups)[x], stringsAsFactors = FALSE)


            })

            groupDF <- bind_rows(groupDF) 
            data <- left_join(data, groupDF, by = "Filename")
        }
        
        
        
        #data <- left_join(clusterDF, scores, by = "Filename")
        data$PCAkey <- data$Filename
        labels <- .makeLabels(data, labels, ...)
        data$Filename <- labels[data$Filename]
        clust <- c()
        data$clust <- as.character(data$clust)
        ## get convex edges
        hulls <- group_by(data, clust)
        
        Dim.1 <- c()
        Dim.2 <- c()
        hulls <- slice(hulls, chull(Dim.1, Dim.2))
        hulls <- ungroup(hulls)
        hulls$cluster <- factor(hulls$clust, levels = unique(hulls$clust))
        
        
        
        PCA <- ggplot() +
            geom_point(data = data, aes_string(group = "Filename", x = "Dim.1", y = "Dim.2"), size = 0.2) +
            geom_polygon(data = hulls, aes_string(x = "Dim.1", y = "Dim.2", fill = "clust"), alpha = 0.4) +
            geom_hline(yintercept=0, colour="darkgrey") + 
            geom_vline(xintercept=0, colour="darkgrey") + 
            theme_bw() +
            theme(
                panel.background = element_blank()
            ) + 
            labs(x = paste0("PC1 (", variance[1], "%)"), y = paste0("PC2 (", variance[2], "%)"))
        
        if (!is.null(userTheme)) nPlot <- nPlot + userTheme
        
        
        if(usePlotly){
            PCA <- ggplotly(PCA)
            
            s <- split(data, data$clust)
            
            PCA$x$data[2:(k+1)] <- lapply(1:k, function(j){
                
                names <- s[[j]]$Filename
                names <- paste(names, collapse = "<br>")
                #PCA$x$data[[j]]$hoveron <- "lines"
                PCA$x$data[[j+1]]$text <- names
                ## add key
                
                #PCA$x$data[[j]] <- c(PCA$x$data[[j]], PCAkey = paste(s$`1`$PCAkey, collapse = " "))
                PCA$x$data[[j+1]]
                
            })  
        }
        
    }
    else{
        
        PCA <- ggplot() +
            geom_point(data = data, aes_string(group = "Filename", x = "Dim.1", y = 'Dim.2')) +
            geom_hline(yintercept=0, colour="darkgrey") + 
            geom_vline(xintercept=0, colour="darkgrey") + 
            theme_bw() +
            theme(
                panel.background = element_blank()
            ) + 
            labs(x = paste0("PC1 (", variance[1], "%)"), y = paste0("PC2 (", variance[2], "%)"))
        
        
        if (!is.null(userTheme)) nPlot <- nPlot + userTheme
        
        
        if(usePlotly){
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
    df <- lapply(split(df, f = df$Filename), function(y){
        Longest_sequence <-
            gsub(".*-([0-9]*)", "\\1", as.character(y$Base))
        Longest_sequence <- max(as.integer(Longest_sequence))
        dfFill <- data.frame(Start = seq_len(Longest_sequence))
        y <- dplyr::right_join(y, dfFill, by = "Start")
        na.locf(y)
    })
    
    df <- dplyr::bind_rows(df)[c("Filename", "Start", "Mean")]
    
    df <- dcast(df, Filename ~ factor(as.character(df$Start), 
                                      levels = unique(as.character(df$Start))), 
                value.var = "Mean", fill = 0) 
    df <- column_to_rownames(df, "Filename")
    
    df 
}

#c("Per_base_sequence_quality", "Per_tile_sequence_quality", 
#                                    "Per_sequence_quality_scores", "Per_base_sequence_content", 
#                                    "Per_sequence_GC_content", "Per_base_N_content", 
#                                    "Sequence_Length_Distribution", "Sequence_Duplication_Levels", 
#                                    "Overrepresented_sequences", "Adapter_Content", "Kmer_Content", 
#                                    "Total_Deduplicated_Percentage")


.generatePer_sequence_quality_scoresPCA <- function(x){
    
    df <- getModule(x, "Per_sequence_quality_scores")
    
    df <- reshape2::dcast(df, Filename ~ factor(as.character(df$Quality), 
                                      levels = unique(as.character(df$Quality))), 
                value.var = "Count", fill = 0) 
    df <- column_to_rownames(df, "Filename")
    
    df 
}  


.generatePer_sequence_GC_contentPCA <- function(x){
    
    df <- getModule(x, "Per_sequence_GC_content")
    
    df <- dcast(df, Filename ~ factor(as.character(df$GC_Content), 
                                      levels = unique(as.character(df$GC_Content))), 
                value.var = "Count", fill = 0) 
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
    
    t <- lapply(c("G", "A", "T", "C"), function(x){
        df <- dcast(df, Filename ~ factor(as.character(df$Start), 
                                          levels = unique(as.character(df$Start))), 
                    value.var = x, fill = 0) 
        
        colnames(df)[2:ncol(df)] <- paste0(colnames(df)[2:ncol(df)], ".", x)
        df
    })
    
    df <- Reduce(function(dtf1,dtf2) left_join(dtf1,dtf2,by="Filename"), t)
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
    
    df <- dcast(df, Filename ~ factor(as.character(df$Lower), 
                                      levels = unique(as.character(df$Lower))), 
                value.var = "Count", fill = 0) 
    df <- column_to_rownames(df, "Filename")
    
    df 
} 