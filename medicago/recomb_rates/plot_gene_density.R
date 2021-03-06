# using data from Tim Paape, 8/17/2016:
# Hi Peter R
# 
# Here are the complete LDhat output files for all 1kb sliding window and all
# chromosomes, with positions of each window on each chromosome (sliding
# windows).  In our GBE paper we published only chromosomes 2, 3 and 5. The
# other 5 chromosomes are unpublished recombination rates  for Medicago, so
# depending on what you want to do perhaps we can have that discussion later. 
# 
# This data comes from SNPs called using our version 3.0 gene annotations (also
# used in the Branca et al. 2011 PNAS paper, 26 accessions). Since then there
# have been v3.5 and 4.0 gene annotations and possible slightly modified
# scaffolds in the genome assembly versions.  Also, if you need I can find the
# centromere positions if you need them for v3.0.
# 
# cheers
# Tim
####
# 
# In short, the LDhat estimates are from the 3.0 assembly, while annotations are from 4.0.
# There exists a 3.5 -> 4.0 liftOver chain file, obtained from
#   https://de.cyverse.org/dl/d/7D271AC5-463F-4840-B1E3-25FC2D5AE015/Mt35.liftover.chain
# (linked to from http://www.medicagogenome.org/downloads )
#
####
# ... BUT as Peter Tiffin says, 8/21/16:
# 
# I checked with Joseph and Peng.  Apparently there are no files that translate
# Mt3.0 to Mt4.0 locations (yes, seems a bit silly).  
# 
# The differences in the Mt3.0 and Mt3.5 assemblies are, however, apparently
# relatively minor and although there is not a liftOver file 3.5 --> 4.0 there
# is a gene conversion table at JCVI Medicago downloads page.  I'm not sure it
# is worth it, but I suppose one could use the Mt3.0 gene names (which should
# be unchanged for Mt3.5 -- just more genes added) and then use for a rough
# translation between 3.0 and 4.0 locations.
#
####

recomb <- read.table("from_paape/07_recom.txt",header=TRUE)
levels(recomb$chr) <- gsub("MtChr","chr",levels(recomb$chr))

# convert to BED
recomb_bed <- data.frame(chrom=recomb$chr,
                         chromStart=recomb$sStart,
                         chromEnd=recomb$sEnd,
                         name=1:nrow(recomb))
write.table(recomb_bed, file="from_paape/07_recomb.bed", row.names=FALSE, quote=FALSE, col.names=FALSE, sep='\t')
# then did liftOver - from source as at http://genome-source.cse.ucsc.edu/gitweb/?p=kent.git;a=blob;f=src/userApps/README
# and 
#  liftOver from_paape/07_recomb.bed liftOver/Mt35.liftover.chain from_paape/07_recomb_mt35.bed from_paape/07_recomb_unmapped.bed 
# producing from_paape/07_recomb_mt35.bed
recomb_mt35 <- read.table("from_paape/07_recomb_mt35.bed", header=FALSE)
names(recomb_mt35) <- c('chrom', 'start', 'end', 'row')
recomb$start <- recomb$end <- rep(NA, nrow(recomb))
recomb$start[recomb_mt35$row] <- recomb_mt35$start
recomb$end[recomb_mt35$row] <- recomb_mt35$end
recomb$mid <- (recomb$start + recomb$end)/2

# map <- read.csv("from_paape/Mtruncatula_mapbased_recomb_2may_b.csv",header=TRUE)
# map <- map[,c("chr","start","end","cM","cm.bp...1.000.000","ave.cM...Mbp....3.window.moving.average")]

mds <- do.call( rbind, lapply( 1:8, function (k) {
                          read.table(file.path("..","results",sprintf("mds_chr%d_window_10000snp.tsv",k)), header=TRUE)
        } ) )
mds$mid <- (mds$start+mds$end)/2
levels(mds$chrom) <- tolower(levels(mds$chrom))

xlims <- lapply(levels(mds$chrom), function (this.chrom) { range(subset(recomb,chr==this.chrom)$mid, subset(mds,chrom==this.chrom)$mid, finite=TRUE) } )
names(xlims) <- levels(mds$chrom)

pdf(file="recomb_and_mds.pdf", width=6, height=6, pointsize=10)
layout( matrix(1:16,nrow=4), heights=c(1,1.2,1,1.2), widths=c(1.2,1,1,1) )
for (this.chrom in paste0('chr',1:8)) {
    left.mar <- if (this.chrom %in% paste0('chr',1:2)) { 4} else {0}
    par(mar=c(0.25,left.mar,2,2)+.1)
    with( subset(mds,chrom==this.chrom), {
         plot(mid,MDS1,col='red',
              xlim=xlims[[this.chrom]],
              ylab='MDS 1',
              xaxt='n', 
              pch=20)
         mtext(3,text=this.chrom)
    } )
    par(mar=c(5,left.mar,0.25,2)+.1)
    with( subset(recomb,chr==this.chrom), {
         plot(mid, rho.mean./1000, pch=20,
              xlim=xlims[[this.chrom]],
              xlab='position (bp)',
              col='blue',
              ylab='recomb rate (cM/Mb)')
    } )
}
dev.off()

average_windows <- function (start,end,value,new.start,new.end) {
    out <- numeric(length(new.start))
    for (k in seq_along(new.start)) {
        weights <- pmax(0,pmin( new.end[k], end ) - pmax( new.start[k], start )) / (end-start)
        out[k] <- sum(weights * value)/sum(weights)
    }
    return(out)
}

stats <- do.call( rbind, lapply( levels(mds$chrom), function (this.chrom) {
                this.breaks <- with(subset(mds,chrom==this.chrom), 
                                    c( start[1], (start[-1]+end[-length(end)])/2, end[length(end)] ) 
                                )
                this.start <- this.breaks[-length(this.breaks)]
                this.end <- this.breaks[-1]
                data.frame(
                           chrom=this.chrom,
                           start=this.start,
                           end=this.end,
                           recomb = with( subset(recomb,chr==this.chrom), 
                                         average_windows( start, end, rho.mean., this.start, this.end ) ),
                           MDS1 = with( subset(mds,chrom==this.chrom), 
                                       average_windows( start, end, MDS1, this.start, this.end ) )
                       )
           } ) )

tapply( 1:nrow(stats), stats$chrom, function (kk) {
           coef( summary( lm( recomb ~ MDS1, data=stats[kk,] ) ) )
        } )

do.call( rbind, 
    tapply( 1:nrow(stats), stats$chrom, function (kk) {
               c( cor=cor( stats$recomb[kk], stats$MDS1[kk], use='pairwise' ), 
               r.squared=( summary( lm( recomb ~ MDS1, data=stats[kk,] ) ) )$r.squared )
            } )
    )

layout( matrix(1:8, nrow=4), widths=c(1.3,1,1,1,1.1) )
par( mar=c(5,4,2,0.25)+.1 )
for (this.chrom in levels(mds$chrom)) {
    with( subset( stats, chrom==this.chrom ), {
             plot( recomb, MDS1, pch=20, main=this.chrom,
                 xlab='recomb. rate',
                 yaxt=if(this.chrom=="chr2L") { 's' } else { 'n' },
                 ylab=if(this.chrom=="chr2L") { "MDS coordinate 1" } else { "" },
                  )
             abline( coef( lm( MDS1 ~ recomb ) ) )
        } )
    if (this.chrom=="chr7") { par( mar=c(5,0.25,2,1)+.1 ) } else { par( mar=c(5,0.25,2,0.25)+.1 ) }
}


