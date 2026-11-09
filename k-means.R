# K-means pada Z-score biaya beli SDR untuk periode 5 tahun dan 1 bulan.
output_dir <- "C:/A MAIN FOLDER/Documents/All in One/R/ADM 2"

packages <- c("readxl", "dplyr", "ggplot2", "factoextra", "cluster",
              "NbClust", "clValid", "hopkins", "corrplot", "ggcorrplot",
              "gridExtra", "knitr", "psych", "fpc", "dendextend",
              "ggrepel", "RColorBrewer", "scales", "tidyr", "MASS", "png")

install_if_missing <- function(pkg) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    install.packages(pkg, dependencies = TRUE)
  }
}

invisible(lapply(packages, install_if_missing))
invisible(lapply(packages, library, character.only = TRUE))

# Impor data
input_file <- "data.xlsx"
if (!file.exists(input_file)) {
  input_file <- file.path(output_dir, input_file)
}
cat(sprintf("Membaca %s.\n", input_file))
df_raw <- read_excel(input_file, .name_repair = "minimal")
headers <- names(df_raw)
header_keys <- gsub("[^a-z0-9]", "", tolower(headers))

find_column <- function(label, aliases) {
  matches <- headers[header_keys %in% aliases]
  if (length(matches) != 1L) {
    detail <- if (length(matches)) paste(matches, collapse = ", ") else "tidak ada"
    stop(sprintf("data.xlsx memerlukan satu kolom %s. Kolom yang cocok: %s.",
                 label, detail), call. = FALSE)
  }
  matches
}

col_currency <- find_column("Currency", c("currency", "currencycode", "matauang", "kodematauang"))
col_negara <- find_column("Negara", c("negara", "namanegara", "country", "countryname"))
col_zscore5 <- find_column("Z-Score 5 Tahun",
                           c("zscore5tahun", "zscore5th", "zscore5yr", "zscore5yrs",
                             "zscore5y", "zscore5year", "zscore5years", "5tahun", "5year", "5years"))
col_zscore1 <- find_column("Z-Score 1 Bulan",
                           c("zscore1bulan", "zscore1bln", "zscore1mo",
                             "zscore1m", "zscore1month", "1bulan", "1month"))
cat(sprintf("Kolom Z-score: %s dan %s.\n", col_zscore5, col_zscore1))

df <- df_raw %>%
  rename(
    Currency   = all_of(col_currency),
    Negara     = all_of(col_negara),
    ZScore_5yr = all_of(col_zscore5),
    ZScore_1mo = all_of(col_zscore1)
  ) %>%
  mutate(
    ZScore_5yr = as.numeric(ZScore_5yr),
    ZScore_1mo = as.numeric(ZScore_1mo)
  ) %>%
  filter(is.finite(ZScore_5yr), is.finite(ZScore_1mo))

df_num <- as.matrix(dplyr::select(df, ZScore_5yr, ZScore_1mo))
rownames(df_num) <- df$Currency
cat(sprintf("%d dari %d observasi memiliki kedua Z-score yang valid.\n", nrow(df), nrow(df_raw)))
if (nrow(df_num) < 3L || any(apply(df_num, 2, function(x) min(x) == max(x)))) {
  stop("Diperlukan minimal tiga observasi valid dan variasi pada kedua kolom Z-score.",
       call. = FALSE)
}

visual_dir <- file.path(output_dir, "visual_clustering")
if (!dir.exists(visual_dir) && !dir.create(visual_dir, recursive = TRUE, showWarnings = FALSE)) {
  stop(sprintf("Tidak dapat membuat folder %s.", visual_dir), call. = FALSE)
}

save_visual <- function(plot, filename, width = 9, height = 6, display = TRUE) {
  path <- file.path(visual_dir, filename)
  if (display) {
    print(plot)
  }
  ggsave(path, plot = plot, width = width, height = height, dpi = 240, bg = "white")
  invisible(path)
}

# Setiap periode menggunakan acuannya sendiri; tanda Z-score menunjukkan posisi terhadap acuan.
score_note <- "Biaya beli SDR di bawah acuan (<0), setara acuan (=0), atau di atas acuan (>0)."

status_zscore <- function(z) {
  dplyr::case_when(
    z < 0 ~ "Di bawah acuan",
    z > 0 ~ "Di atas acuan",
    TRUE ~ "Setara acuan"
  )
}

cat("\nStruktur data\n")
str(df)

cat("\nStatistik deskriptif\n")
desc_stats <- df_num %>%
  psych::describe() %>%
  dplyr::select(n, mean, sd, min, max, skew, kurtosis)
print(round(desc_stats, 4))

p_hist1 <- ggplot(df, aes(x = ZScore_5yr)) +
  geom_histogram(aes(y = after_stat(density)), bins = 15,
                 fill = "#2196F3", color = "white", alpha = 0.8) +
  geom_density(color = "#0D47A1", linewidth = 1) +
  labs(title = "Distribusi Z-Score 5 Tahun",
       x = "Z-Score 5 Tahun", y = "Density") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

p_hist2 <- ggplot(df, aes(x = ZScore_1mo)) +
  geom_histogram(aes(y = after_stat(density)), bins = 15,
                 fill = "#FF5722", color = "white", alpha = 0.8) +
  geom_density(color = "#BF360C", linewidth = 1) +
  labs(title = "Distribusi Z-Score 1 Bulan",
       x = "Z-Score 1 Bulan", y = "Density") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

p_scatter <- ggplot(df, aes(x = ZScore_5yr, y = ZScore_1mo)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "gray50") +
  geom_vline(xintercept = 0, linetype = "dashed", color = "gray50") +
  geom_point(size = 3, color = "#27833D", alpha = 0.9) +
  geom_text_repel(aes(label = Currency), size = 3, max.overlaps = 20, seed = 123) +
  labs(title = "Z-score biaya beli SDR per mata uang",
       subtitle = score_note,
       x = "Z-score 5 tahun",
       y = "Z-score 1 bulan") +
  theme_minimal(base_size = 12) +
  theme(plot.title    = element_text(face = "bold"),
        plot.subtitle = element_text(color = "gray40", size = 9))

p_eda <- grid.arrange(p_hist1, p_hist2, p_scatter, layout_matrix = rbind(c(1, 2), c(3, 3)))
save_visual(p_eda, "01-eksplorasi-z-score.png", width = 11, height = 9, display = FALSE)

cat("\nPencilan menurut IQR\n")
p_box1 <- ggplot(df, aes(y = ZScore_5yr)) +
  geom_boxplot(fill = "#2196F3", alpha = 0.7, outlier.color = "red",
               outlier.size = 3) +
  labs(title = "Boxplot Z-Score 5 Tahun", y = "Z-Score 5 Tahun") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

p_box2 <- ggplot(df, aes(y = ZScore_1mo)) +
  geom_boxplot(fill = "#FF5722", alpha = 0.7, outlier.color = "red",
               outlier.size = 3) +
  labs(title = "Boxplot Z-Score 1 Bulan", y = "Z-Score 1 Bulan") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))

p_box <- grid.arrange(p_box1, p_box2, ncol = 2)
save_visual(p_box, "02-pencilan.png", width = 10, height = 5.5, display = FALSE)

detect_outliers <- function(x, var_name) {
  Q1 <- quantile(x, 0.25); Q3 <- quantile(x, 0.75)
  IQR_val <- Q3 - Q1
  lower <- Q1 - 1.5 * IQR_val; upper <- Q3 + 1.5 * IQR_val
  outliers <- which(x < lower | x > upper)
  cat(sprintf("Variabel %s: Batas bawah = %.3f, Batas atas = %.3f\n",
              var_name, lower, upper))
  if (length(outliers) > 0) {
    cat(sprintf("  Pencilan: %s\n",
                paste(df$Currency[outliers], collapse = ", ")))
  } else {
    cat("  Tidak ada pencilan.\n")
  }
  return(outliers)
}

out1 <- detect_outliers(df$ZScore_5yr, "Z-Score 5 Tahun")
out2 <- detect_outliers(df$ZScore_1mo, "Z-Score 1 Bulan")

cat("\nKorelasi Spearman\n")
cor_matrix <- cor(df_num, method = "spearman")
print(round(cor_matrix, 4))

r_val <- cor_matrix[1, 2]
cat(sprintf("\nKoefisien Spearman: %.4f\n", r_val))
if (abs(r_val) > 0.9) {
  cat("Korelasi absolut di atas 0,9.\n")
} else if (abs(r_val) > 0.7) {
  cat("Korelasi absolut di atas 0,7 hingga 0,9.\n")
} else {
  cat("Korelasi absolut tidak melebihi 0,7.\n")
}

p_corr <- ggcorrplot(cor_matrix, method = "circle", type = "lower",
                    lab = TRUE, lab_size = 5,
                    title = "Korelasi Spearman antar Z-score",
                    colors = c("#F44336", "white", "#2196F3")) +
  theme(plot.title = element_text(face = "bold", hjust = 0.5))
save_visual(p_corr, "03-korelasi-spearman.png")

cat("\nSkala Z-score pada data yang dianalisis\n")
apply(df_num, 2, function(x) c(Mean = mean(x), SD = sd(x), Min = min(x), Max = max(x))) %>%
  round(4) %>% print()

set.seed(123)
hop_m <- max(1L, floor(nrow(df_num) / 10))
hop_val <- hopkins::hopkins(df_num, m = hop_m)

# Perbandingan jumlah cluster
cat("\nPemilihan jumlah cluster\n")
set.seed(123)

distinct_scores <- nrow(unique(df_num))
k_max <- min(10L, nrow(df_num) - 1L, distinct_scores)
cat("Metode elbow (WSS)\n")
p_elbow <- fviz_nbclust(df_num, kmeans, method = "wss", k.max = k_max) +
  labs(title = "WSS menurut jumlah cluster") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))
save_visual(p_elbow, "04-elbow-wss.png")

cat("\nRata-rata silhouette\n")
p_sil_choice <- fviz_nbclust(df_num, kmeans, method = "silhouette", k.max = k_max) +
  labs(title = "Rata-rata silhouette menurut jumlah cluster") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))
save_visual(p_sil_choice, "05-pemilihan-silhouette.png")

cat("\nGap statistic\n")
gap_stat <- clusGap(df_num, FUN = kmeans, nstart = 25,
                   K.max = k_max, B = 50)
p_gap <- fviz_gap_stat(gap_stat) +
  labs(title = "Gap statistic menurut jumlah cluster") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))
save_visual(p_gap, "06-gap-statistic.png")

print(gap_stat$Tab)
k_gap <- maxSE(gap_stat$Tab[,"gap"], gap_stat$Tab[,"SE.sim"], method = "firstSEmax")

run_nbclust <- function(data, max_clusters, paths) {
  # NbClust menggambar Hubert dan D-index sebagai dua halaman grafik dasar.
  pattern <- tempfile("nbclust-", fileext = "-%02d.png")
  captures <- sprintf(pattern, 1:2)
  on.exit(unlink(captures))
  grDevices::png(pattern, width = 11, height = 5.5, units = "in", res = 240, bg = "white")
  device <- grDevices::dev.cur()
  tryCatch(
    invisible(capture.output(
      result <- NbClust(data = data, distance = "euclidean", min.nc = 2,
                        max.nc = max_clusters, method = "kmeans", index = "all")
    )),
    finally = grDevices::dev.off(device)
  )

  if (!all(file.copy(captures, paths, overwrite = TRUE))) {
    stop("Grafik NbClust gagal disimpan.", call. = FALSE)
  }
  for (path in paths) {
    grid::grid.newpage()
    grid::grid.raster(png::readPNG(path, native = TRUE))
  }
  result
}

cat("\nNbClust (index = all)\n")
nb_max <- min(8L, nrow(df_num) - 2L, distinct_scores - 1L)
nb_paths <- file.path(visual_dir, c("07-nbclust-hubert.png", "08-nbclust-d-index.png"))
k_nb <- "tidak ada"
if (nb_max >= 4L) {
  nb <- run_nbclust(df_num, nb_max, nb_paths)
  recommendations <- nb$Best.nc[1, ]
  nb_votes <- table(recommendations[recommendations %in% seq.int(2L, nb_max)])
  if (length(nb_votes)) {
    print(nb_votes)
    k_nb <- names(which.max(nb_votes))
  }
} else {
  if (unlink(nb_paths) != 0L) {
    stop("Grafik NbClust dari analisis sebelumnya gagal dihapus.", call. = FALSE)
  }
  cat("Jumlah observasi berbeda tidak mencukupi untuk rentang k pada NbClust.\n")
}
cat(sprintf("Rekomendasi jumlah cluster: Gap statistic %d, NbClust %s.\n", k_gap, k_nb))

# Jumlah cluster ditetapkan manual setelah meninjau diagnostik.
k_final <- 2
if (k_final < 2L || k_final >= nrow(df_num) || k_final > distinct_scores) {
  stop("Jumlah cluster harus minimal 2, lebih kecil dari jumlah observasi, dan tidak melebihi jumlah observasi berbeda.",
       call. = FALSE)
}
cat(sprintf("\nK-means dengan k = %d\n", k_final))
set.seed(123)
km_result <- kmeans(df_num, centers = k_final, nstart = 50, iter.max = 100)

cat(sprintf("Total SS: %.4f\n", km_result$totss))

df$Cluster <- factor(km_result$cluster)
df_export <- df %>%
  mutate(Status_5yr = status_zscore(ZScore_5yr),
         Status_1mo = status_zscore(ZScore_1mo))

cat("\nCentroid cluster\n")
centroid_df <- as.data.frame(km_result$centers)
centroid_df$Cluster <- paste0("Cluster ", 1:k_final)
centroid_df <- centroid_df[, c("Cluster", "ZScore_5yr", "ZScore_1mo")]
centroid_table <- centroid_df %>% mutate(across(where(is.numeric), ~ round(.x, 4)))
print(centroid_table, row.names = FALSE)

cat("\nUkuran cluster\n")
size_df <- data.frame(Cluster = paste0("Cluster ", 1:k_final),
                      Jumlah = km_result$size)
print(size_df)

cat("\nAnggota per cluster\n", score_note, "\n", sep = "")
for (i in 1:k_final) {
  members <- df_export %>% filter(Cluster == i) %>%
    dplyr::select(Currency, Negara, ZScore_5yr, ZScore_1mo, Status_5yr, Status_1mo)
  cat(sprintf("\nCluster %d (%d anggota)\n", i, nrow(members)))
  print(as.data.frame(members), row.names = FALSE)
}

cat("\nEvaluasi cluster\n")
sil <- silhouette(km_result$cluster, dist(df_num))
sil_avg <- mean(sil[, 3])

p_sil <- fviz_silhouette(sil, palette = "jco") +
  labs(title = sprintf("Silhouette untuk k = %d (rata-rata %.4f)", k_final, sil_avg),
       subtitle = "Nilai negatif menunjukkan observasi lebih dekat ke cluster lain.") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"))
save_visual(p_sil, "09-evaluasi-silhouette.png")

neg_sil <- which(sil[, 3] < 0)
if (length(neg_sil) > 0) {
  cat(sprintf("\n%d observasi memiliki silhouette negatif:\n",
              length(neg_sil)))
  cat(paste(df$Currency[neg_sil], collapse = ", "), "\n")
} else {
  cat("\nTidak ada observasi dengan silhouette negatif.\n")
}

cluster_metrics <- fpc::cluster.stats(dist(df_num), km_result$cluster)
dunn_val <- cluster_metrics$dunn
wb_ratio <- cluster_metrics$wb.ratio

eval_df <- data.frame(
  Metrik = c("Within-Cluster SS", "Between-Cluster SS",
             "Rasio Between/Total (%)", "Silhouette (avg)",
             "Indeks Dunn", "Rasio jarak dalam/antar cluster"),
  Nilai  = round(c(km_result$tot.withinss, km_result$betweenss,
                   km_result$betweenss/km_result$totss * 100,
                   sil_avg, dunn_val, wb_ratio), 4),
  Interpretasi = c("Semakin kecil = lebih baik",
                   "Semakin besar = lebih baik",
                   "Semakin tinggi = lebih baik",
                   "Semakin mendekati 1 = lebih baik",
                   "Semakin besar = lebih baik",
                   "Semakin kecil = lebih baik")
)
print(eval_df, row.names = FALSE)

# Grafik hasil clustering
p_size <- ggplot(size_df, aes(x = Cluster, y = Jumlah, fill = Cluster)) +
  geom_col(alpha = 0.85, width = 0.6) +
  geom_text(aes(label = Jumlah), vjust = -0.5, fontface = "bold") +
  scale_fill_brewer(palette = "Set1") +
  labs(title = "Jumlah Anggota per Cluster",
       x = "Cluster", y = "Jumlah Mata Uang") +
  theme_minimal(base_size = 12) +
  theme(plot.title = element_text(face = "bold"), legend.position = "none")

save_visual(p_size, "10-ukuran-cluster.png")

profile_df <- df %>%
  group_by(Cluster) %>%
  summarise(
    `Z-Score 5 Tahun (Avg)` = mean(ZScore_5yr),
    `Z-Score 1 Bulan (Avg)` = mean(ZScore_1mo),
    .groups = "drop"
  ) %>%
  pivot_longer(cols = -Cluster, names_to = "Variabel", values_to = "Nilai")

p_profile <- ggplot(profile_df, aes(x = Variabel, y = Nilai,
                                    fill = Cluster, group = Cluster)) +
  geom_col(position = "dodge", alpha = 0.85, width = 0.6) +
  geom_hline(yintercept = 0, color = "black", linewidth = 0.5) +
  scale_fill_brewer(palette = "Set1") +
  labs(title = "Profil Rata-Rata Z-Score per Cluster",
       subtitle = score_note,
       x = NULL, y = "Rata-rata Z-score", fill = "Cluster") +
  theme_minimal(base_size = 12) +
  theme(plot.title    = element_text(face = "bold"),
        plot.subtitle = element_text(color = "gray40", size = 9),
        axis.text.x   = element_text(size = 11))

save_visual(p_profile, "11-profil-cluster.png", width = 10)

df_heat <- df %>%
  arrange(Cluster) %>%
  mutate(Currency = factor(Currency, levels = Currency))

df_heat_long <- df_heat %>%
  pivot_longer(cols = c(ZScore_5yr, ZScore_1mo),
               names_to = "Variabel", values_to = "Nilai")

p_heat <- ggplot(df_heat_long, aes(x = Variabel, y = Currency, fill = Nilai)) +
  geom_tile(color = "white", linewidth = 0.5) +
  geom_text(aes(label = round(Nilai, 2)), size = 3, color = "black") +
  scale_fill_gradient2(low  = "#4C85C2",
                       mid  = "white",
                       high = "#D65C56",
                       midpoint = 0,
                       name = "Z-score") +
  facet_grid(Cluster ~ ., scales = "free_y", space = "free_y") +
  labs(title = "Heatmap Z-Score per Mata Uang (Dikelompokkan per Cluster)",
       subtitle = score_note,
       x = "Variabel", y = "Mata Uang") +
  theme_minimal(base_size = 11) +
  theme(plot.title    = element_text(face = "bold"),
        plot.subtitle = element_text(color = "gray40", size = 9),
        axis.text.x   = element_text(angle = 15, hjust = 1),
        strip.text    = element_text(face = "bold"))

heatmap_height <- min(32, max(7, 2 + 0.16 * nrow(df)))
save_visual(p_heat, "12-heatmap-z-score.png", width = 10, height = heatmap_height)

# Perbandingan deskriptif antar cluster
cat("\nProfil deskriptif cluster\n")
cat("Kedua Z-score digunakan untuk membentuk cluster. Tabel ini merangkum perbedaan yang teramati.\n")
cluster_profile <- df %>%
  group_by(Cluster) %>%
  summarise(
    N = n(),
    ZScore5_Mean = mean(ZScore_5yr),
    ZScore5_SD = sd(ZScore_5yr),
    ZScore5_Min = min(ZScore_5yr),
    ZScore5_Max = max(ZScore_5yr),
    ZScore1_Mean = mean(ZScore_1mo),
    ZScore1_SD = sd(ZScore_1mo),
    ZScore1_Min = min(ZScore_1mo),
    ZScore1_Max = max(ZScore_1mo),
    .groups = "drop"
  )

profile_table <- cluster_profile %>% mutate(across(where(is.numeric), ~ round(.x, 4)))
print(as.data.frame(profile_table), row.names = FALSE)

# Ekspor hasil
if (requireNamespace("openxlsx", quietly = TRUE)) {
  output_file <- file.path(output_dir, "hasil_kmeans_clustering.xlsx")
  wb <- openxlsx::createWorkbook()

  eval_export <- data.frame(
    Metrik = c("Jumlah cluster yang digunakan (k)", "Statistik Hopkins"),
    Nilai = c(k_final, round(hop_val, 4)),
    Interpretasi = c("Ditetapkan manual", "Kecenderungan pengelompokan")
  )

  legenda_df <- data.frame(
    Kolom = c("ZScore_5yr", "ZScore_1mo", "Status_5yr", "Status_1mo"),
    Penjelasan = c(
      "Z-score biaya beli SDR untuk periode 5 tahun",
      "Z-score biaya beli SDR untuk periode 1 bulan",
      "Posisi biaya beli SDR terhadap acuan 5 tahun",
      "Posisi biaya beli SDR terhadap acuan 1 bulan"
    ),
    Interpretasi_Nilai = c(
      score_note,
      score_note,
      "Di bawah, setara, atau di atas acuan",
      "Di bawah, setara, atau di atas acuan"
    )
  )

  tables <- list(
    "Data + Cluster" = df_export,
    "Centroid Cluster" = centroid_table,
    "Profil Cluster" = profile_table,
    "Evaluasi" = rbind(eval_export, eval_df),
    "Legenda Interpretasi" = legenda_df
  )
  for (sheet in names(tables)) {
    openxlsx::addWorksheet(wb, sheet)
    openxlsx::writeData(wb, sheet, tables[[sheet]])
  }

  openxlsx::saveWorkbook(wb, output_file, overwrite = TRUE)
  cat(sprintf("\nHasil disimpan ke %s.\n", output_file))
} else {
  output_file <- file.path(output_dir, "hasil_kmeans_clustering.csv")
  write.csv(df_export, output_file, row.names = FALSE)
  cat(sprintf("\nTabel utama disimpan ke %s (paket openxlsx tidak tersedia).\n", output_file))
}

cat("\nRingkasan\n")
cat(sprintf("Jumlah cluster yang digunakan: %d\n", k_final))
cat(sprintf("Statistik Hopkins: %.4f\n", hop_val))
cat(sprintf("Rata-rata silhouette: %.4f\n", sil_avg))
cat(sprintf("Indeks Dunn: %.4f\n", dunn_val))

# Tampilkan hasil utama terakhir agar tetap terlihat pada panel plot.
labels_per_cluster <- min(8L, max(1L, 24L %/% k_final))
plot_labels <- df %>%
  arrange(Cluster, ZScore_5yr, ZScore_1mo, Currency) %>%
  group_by(Cluster) %>%
  mutate(
    Label = if_else(
      row_number() %in% round(seq(1L, n(), length.out = min(n(), labels_per_cluster))),
      coalesce(as.character(Currency), ""),
      ""
    )
  ) %>%
  ungroup()

plot_caption <- "Bintang menandai pusat cluster. Garis putus-putus menandai Z-score nol."
if (any(plot_labels$Label == "")) {
  plot_caption <- paste(plot_caption, "Sebagian kode ditampilkan agar grafik mudah dibaca.", sep = "\n")
}
plot_labels <- bind_rows(
  plot_labels,
  transmute(centroid_df, ZScore_5yr, ZScore_1mo, Label = "")
)

p_cluster_scatter <- ggplot(df, aes(x = ZScore_5yr, y = ZScore_1mo)) +
  geom_hline(yintercept = 0, linetype = "dashed", color = "#707983", linewidth = 0.5) +
  geom_vline(xintercept = 0, linetype = "dashed", color = "#707983", linewidth = 0.5) +
  geom_point(aes(color = Cluster, shape = Cluster), size = 3.4) +
  geom_point(data = centroid_df, shape = 8, size = 4.5, color = "#171D24", stroke = 1.1) +
  geom_text_repel(data = plot_labels, aes(label = Label), color = "#171D24", size = 3.9,
                  box.padding = 0.5, point.padding = 0.35, point.size = 4.5, seed = 123,
                  segment.color = "#707983", max.overlaps = Inf) +
  scale_color_viridis_d(begin = 0.1, end = 0.52) +
  scale_shape_manual(values = rep(c(16, 17, 15, 18, 3, 4), length.out = k_final)) +
  scale_x_continuous(expand = expansion(mult = 0.1)) +
  scale_y_continuous(expand = expansion(mult = 0.1)) +
  coord_equal() +
  labs(title = "Cluster mata uang berdasarkan biaya beli SDR",
       subtitle = sprintf("K-means dengan %d cluster", k_final),
       x = "Z-score 5 tahun",
       y = "Z-score 1 bulan",
       caption = plot_caption) +
  theme_minimal(base_size = 15) +
  theme(plot.title = element_text(face = "bold", size = 18, color = "#171D24"),
        plot.subtitle = element_text(color = "#394552", margin = margin(b = 9)),
        plot.caption = element_text(color = "#394552", hjust = 0),
        axis.text = element_text(color = "#394552"),
        panel.grid.minor = element_blank(),
        plot.background = element_rect(fill = "white", color = NA),
        legend.position = "bottom",
        plot.margin = margin(12, 16, 12, 16))

plot_file <- file.path(output_dir, "plot_cluster_mata_uang.png")
main_visual <- save_visual(p_cluster_scatter, "13-plot-cluster-mata-uang.png", width = 9, height = 8.4)
if (!file.copy(main_visual, plot_file, overwrite = TRUE)) {
  stop(sprintf("Grafik utama gagal disalin ke %s.", plot_file), call. = FALSE)
}
cat(sprintf("Grafik disimpan di folder %s. Salinan grafik utama: %s.\n", visual_dir, plot_file))
