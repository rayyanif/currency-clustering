# Currency Clustering Against the SDR

**English** · [Bahasa Indonesia](README.id.md)

K-means groups **155 currencies** by how their exchange rate against the Special Drawing Right (SDR) compares with their own five-year and one-month reference periods. The selected fit has **two clusters**, with 60 and 95 currencies. The Indonesian rupiah (IDR) is in Cluster 2, with an above-reference SDR cost in both periods.

## Data and features

The analysis uses daily mid-market exchange rates from Xe, expressed as **units of local currency per SDR**. Xe labels the SDR as `XDR`. The input workbook, `data.xlsx`, contains one row per currency code and two precomputed Z-scores. All 155 rows had finite values for both scores. [Xe Currency Tables for XDR](https://www.xe.com/currencytables/?from=XDR)

Each score is `(observed rate − reference-period mean) / reference-period standard deviation` for that currency. A positive score means more local currency units are needed per SDR than the currency's reference-period average. A negative score means fewer units are needed, and zero matches the reference. K-means uses the two scores directly, with Euclidean distance and no additional rescaling.

| Feature | Mean | Sample SD | Minimum | Maximum |
| --- | ---: | ---: | ---: | ---: |
| Five-year Z-score | 0.1645 | 1.2513 | −2.5651 | 3.8890 |
| One-month Z-score | −0.0638 | 0.9382 | −2.9562 | 2.6344 |

The five-year scores have a wider central spread. The 1.5×IQR rule flags **IRR** on the five-year score and **16 currencies** on the one-month score, including **JPY** on the low side and **BIF** on the high side. All flagged rows remain in the fit. The two scores have a Spearman rank correlation of **0.4958**, so currencies that rank high in one window tend to rank higher in the other, with room for different profiles such as JPY.

<details>
<summary>Exploratory plots and correlation (3 figures)</summary>

![Five-year and one-month score distributions with a scatterplot of both scores](assets/currency-clustering/01-eksplorasi-z-score.png)

![Boxplots highlighting one five-year outlier and several one-month outliers](assets/currency-clustering/02-pencilan.png)

![Spearman correlation between the two scores, rounded to 0.5 on the plot](assets/currency-clustering/03-korelasi-spearman.png)

</details>

## Why two clusters?

| Diagnostic | Result |
| --- | --- |
| Within-cluster sum of squares (WSS) | The largest drop is from one to two clusters. WSS keeps falling as more clusters are added. |
| Average silhouette | Peaks at `k = 2` among the tested solutions with 2–10 clusters. |
| Gap statistic | Selects `k = 2` using `firstSEmax`. The gap at two clusters is 0.5896, based on 50 reference simulations. |
| NbClust | `k = 2` receives the most votes, 10 of the 23 recommendations in the tested range of 2–8. The Hubert and D-index plots show two visual diagnostics from this step. |

The final script sets `k = 2` after reviewing the diagnostics and fits K-means with `set.seed(123)`, 50 starts and a 100-iteration limit. The Hopkins statistic of **0.9073** indicates a tendency to cluster in this score space. The count of clusters comes from the diagnostics above. [R documentation for Hopkins](https://search.r-project.org/CRAN/refmans/hopkins/html/hopkins.html)

<details>
<summary>Cluster count diagnostics (5 figures)</summary>

![WSS curve with its largest drop between one and two clusters](assets/currency-clustering/04-elbow-wss.png)

![Average silhouette by cluster count, highest at two clusters](assets/currency-clustering/05-pemilihan-silhouette.png)

![Gap statistic and error bars for cluster counts one through ten](assets/currency-clustering/06-gap-statistic.png)

![NbClust Hubert statistic and second differences](assets/currency-clustering/07-nbclust-hubert.png)

![NbClust D-index and second differences](assets/currency-clustering/08-nbclust-d-index.png)

</details>

## Cluster profiles and the rupiah

| Cluster | Currencies | Five-year centroid | One-month centroid | Example members |
| --- | ---: | ---: | ---: | --- |
| 1 | 60 | −1.0578 | −0.7796 | EUR, GBP, AUD, SGD, JPY |
| 2 | 95 | +0.9365 | +0.3883 | IDR, INR, PHP, TRY, EGP |

Cluster 1 averages below its members' references on both scores, while Cluster 2 averages above them. The centroid gap is larger for the five-year score. Members can still have mixed signs. For example, JPY is in Cluster 1 with a positive five-year score and a strongly negative one-month score.

![K-means scatterplot with five-year scores on the horizontal axis, one-month scores on the vertical axis and stars at the centroids](assets/currency-clustering/13-plot-cluster-mata-uang.png)

IDR's scores are **+2.5193 (five-year)** and **+1.3437 (one-month)**. By Euclidean distance in these two features, **INR and BTN tie as the closest matches (0.6415)**, followed by NPR (0.6496) and MUR (0.6575). PHP is also in Cluster 2, at a distance of 0.7525. These distances compare the two standardized deviations. Identifying common causes or similar day-to-day exchange-rate movements would require other data.

## Cluster quality

The final model's average silhouette is **0.4938**, with cluster averages of **0.51** and **0.49**. This indicates moderate separation. **CNH** is the only currency with a negative silhouette, meaning it is closer on average to members of the other cluster. The between-cluster share of total sum of squares is **52.14%**. The Dunn index is **0.0580**, and the ratio of mean within-cluster distance to mean between-cluster distance (`wb.ratio`) is **0.4943**. [R documentation for `cluster.stats`](https://search.r-project.org/CRAN/refmans/fpc/html/cluster.stats.html)

<details>
<summary>Silhouette, membership counts, profiles and heatmap (4 figures)</summary>

![Silhouette widths for the final fit, with one negative observation](assets/currency-clustering/09-evaluasi-silhouette.png)

![Membership counts of 60 for Cluster 1 and 95 for Cluster 2](assets/currency-clustering/10-ukuran-cluster.png)

![Mean Z-scores by cluster, with negative means for Cluster 1 and positive means for Cluster 2](assets/currency-clustering/11-profil-cluster.png)

![Heatmap of both Z-scores for all 155 currencies, grouped by cluster](assets/currency-clustering/12-heatmap-z-score.png)

</details>

## Run the analysis

1. Put `data.xlsx` and the K-means R script in the same folder. The local script used for these results is named `k-means.R`.
2. Open the folder in RStudio or set it as the R working directory. Set `output_dir <- getwd()` at the top of the script to write results there.
3. Run the script. It installs any missing analysis packages. With `openxlsx` installed, it writes `hasil_kmeans_clustering.xlsx` with currency assignments, centroids, cluster profiles, diagnostics and a column guide. Otherwise it writes the assignments to `hasil_kmeans_clustering.csv`.

The script saves figures in `visual_clustering/` and copies the final scatterplot to `plot_cluster_mata_uang.png`.

## Analysis notes

The accompanying report, *Analisis Klaster K-Means pada Nilai Tukar 155 Mata Uang terhadap Special Drawing Rights (SDR) dengan Standarisasi Z-Score*, also discusses multidimensional scaling (MDS) and a Kruskal–Wallis comparison after clustering. The results and figures here follow the supplied R run, which clusters the two original score columns. A comparison on those same scores describes differences in the fitted groups.
