// =============================================================================
// paper1/stan/t4_state_space.stan
//
// T4 -- State-space Bayesiano CS-consistente para tres SPF centro-sur Chile.
// Schaefer en log-escala con shifters ambientales (SST, CHL) y correlación
// cruzada de error de proceso entre especies.
//
// Diseñado para:
//   - anchoveta_cs   (SSB SCAA IFOP 1997-2024; observación densa, precisa)
//   - sardina_comun_cs (SSB SCAA IFOP 1991-2024; observación densa, precisa)
//   - jurel_cs       (biomasa acústica IFOP 2000-2024 con 7 gaps MAR + 2 left-
//                     censored no-detecciones en 2012 y 2015)
//
// Decisiones arquitectónicas (documentadas en YAML):
//
// (D1) NO-CENTERED en log-escala para r, K y B_latent. La parametrización
//      centered produce funnels en cadenas cortas para state-space con poca
//      data (25-34 obs/stock). Log-escala además garantiza positividad sin
//      truncar.
//
// (D2) Shifters rho_SST y rho_CHL stock-específicos (vector[S], no jerárquico).
//      Motivación YAML/advertencia_contra_jerarquico: los signos de rho_CHL
//      difieren entre anchoveta (-2.3) y sardina (+2.1); pool parcial los
//      aplastaría a cero.
//
// (D3) LKJ(2) sobre cholesky factor de la correlación de ruido de proceso:
//      débilmente informativo hacia independencia pero no la impone. El mismo
//      regime shift climático (p.ej. ENSO) puede mover a las 3 especies en
//      direcciones correlacionadas.
//
// (D4) OBSERVACIÓN stock-específica:
//        - anchoveta_cs, sardina_comun_cs: log-normal con sigma_obs pequeño
//          (σ≈0.1-0.15), porque la SSB SCAA es ya un resumen suavizado.
//        - jurel_cs: log-normal con sigma_obs mayor (σ≈0.3), porque el crucero
//          acústico es un snapshot con varianza de muestreo alta. MAR para
//          gaps y left-censored para no-detecciones 2012 (2547 t) y 2015 (0 t).
//
// (D5) Captura como DATO (no latente). Las reportadas por SERNAPESCA tienen
//      error relativo <<< al de la biomasa acústica; asumir C exacto es
//      estándar en Schaefer/Bayes-SP (Punt 2019). Un futuro T5 puede
//      relajarlo.
//
// Unidades: toda biomasa en miles de toneladas (mil_t). Captura idem.
//   - SST: anomalía centrada (°C - media 2000-2024)
//   - log_CHL: log(chl) centrada (log(mg/m3) - media del log)
// =============================================================================

functions {
  // Dinámica Schaefer determinística un paso adelante, en LOG-biomasa:
  //    B_{t+1} = B_t + r_t * B_t * (1 - B_t/K) - C_t
  // Devuelve log(B_{t+1}) dado log(B_t), con floor numérico para evitar
  // log(negativo) si C_t > B_t + r_t * B_t * (1 - B_t/K).
  real schaefer_step_log(real logB, real logK, real r_t, real C) {
    real B   = exp(logB);
    real K   = exp(logK);
    real g   = r_t * B * (1.0 - B / K);
    real B1  = B + g - C;
    // floor: 1% de K. Esto NO es identificación; solo evita NaN en leapfrog.
    real floor = 0.01 * K;
    return log(fmax(floor, B1));
  }
}

data {
  // -------------------- Dimensiones --------------------
  int<lower=1> S;                        // #stocks (3: anchoveta, sardina, jurel)
  int<lower=1> T;                        // #años en la ventana común (p.ej. 2000-2024 → T=25)
  int<lower=1> N_obs_anchoveta;          // #obs válidas SSB anchoveta
  int<lower=1> N_obs_sardina;            // #obs válidas SSB sardina
  int<lower=1> N_obs_jurel_uncensored;   // #obs acústicas jurel sin censura
  int<lower=0> N_obs_jurel_censored;     // #obs acústicas jurel left-censored (0 o muy bajas)

  // -------------------- Índices de observación --------------------
  // Para cada obs, qué año del vector [1..T] le corresponde (1-indexed).
  array[N_obs_anchoveta] int<lower=1, upper=T> t_anchoveta;
  array[N_obs_sardina]   int<lower=1, upper=T> t_sardina;
  array[N_obs_jurel_uncensored] int<lower=1, upper=T> t_jurel_unc;
  array[N_obs_jurel_censored]   int<lower=1, upper=T> t_jurel_cen;

  // -------------------- Datos observados --------------------
  vector<lower=0>[N_obs_anchoveta]        B_obs_anchoveta; // mil t (SSB)
  vector<lower=0>[N_obs_sardina]          B_obs_sardina;   // mil t (SSB)
  vector<lower=0>[N_obs_jurel_uncensored] B_obs_jurel;     // mil t (acústica)
  real<lower=0> B_censor_limit_jurel;                      // mil t; límite superior censura
                                                           // (≈ 3 mil t, ver yaml jurel_cs.no_detecciones)

  // Captura anual por stock (fila = año 1..T, col = stock 1..S)
  // Orden columnas: 1=anchoveta_cs, 2=sardina_comun_cs, 3=jurel_cs
  matrix<lower=0>[T, S] C;

  // Covariables ambientales (un vector común para los 3 stocks)
  vector[T] SST_c;        // SST anomalía centrada (°C)
  vector[T] logCHL_c;     // log(CHL) centrado

  // -------------------- Priors informativos (por stock) --------------------
  // Escalares derivados del YAML. Orden: [anchoveta, sardina, jurel].
  vector<lower=0>[S] r_prior_mean;        // YAML priors_biologicos.r_prior_mean
  vector<lower=0>[S] r_prior_sd;
  vector<lower=0>[S] K_prior_mean;        // mil t, YAML K_prior_mean_mil_t
  vector<lower=0>[S] K_prior_sd;

  // Shifters: priors derivados de t3bis_stress_test_rerun_2026_04_22
  vector[S] rho_sst_prior_mean;
  vector<lower=0>[S] rho_sst_prior_sd;
  vector[S] rho_chl_prior_mean;
  vector<lower=0>[S] rho_chl_prior_sd;

  // Biomasa inicial B_0 (año 1). Informativo desde assessment.
  vector<lower=0>[S] B0_prior_mean;       // mil t
  vector<lower=0>[S] B0_prior_sd;

  // Ruido de observación: prior stock-específico porque sardina/anchoveta
  // (SCAA suavizado) tienen σ mucho menor que jurel (acústico).
  vector<lower=0>[S] sigma_obs_prior_mean;  // escala log-normal observación
  vector<lower=0>[S] sigma_obs_prior_sd;

  // Ruido de proceso: prior común débil
  real<lower=0> sigma_proc_prior_mean;
  real<lower=0> sigma_proc_prior_sd;
}

transformed data {
  // Índice fijo de stocks (para legibilidad)
  int IDX_ANCH = 1;
  int IDX_SARD = 2;
  int IDX_JUR  = 3;

  // Log-transformaciones de priors (trabajamos en log-escala para r, K, B)
  vector[S] log_r_prior_mean;
  vector[S] log_r_prior_sd;
  vector[S] log_K_prior_mean;
  vector[S] log_K_prior_sd;
  vector[S] log_B0_prior_mean;
  vector[S] log_B0_prior_sd;

  for (s in 1:S) {
    // Conversión moment-matching normal→lognormal aproximada:
    //   si X ~ N(μ, σ²), usar log(μ) como mean y σ/μ como CV ≈ sd lognormal
    log_r_prior_mean[s]  = log(r_prior_mean[s]);
    log_r_prior_sd[s]    = r_prior_sd[s] / r_prior_mean[s];
    log_K_prior_mean[s]  = log(K_prior_mean[s]);
    log_K_prior_sd[s]    = K_prior_sd[s] / K_prior_mean[s];
    log_B0_prior_mean[s] = log(B0_prior_mean[s]);
    log_B0_prior_sd[s]   = B0_prior_sd[s] / B0_prior_mean[s];
  }

  // Log de observaciones para likelihood log-normal
  vector[N_obs_anchoveta]        log_B_obs_anchoveta = log(B_obs_anchoveta);
  vector[N_obs_sardina]          log_B_obs_sardina   = log(B_obs_sardina);
  vector[N_obs_jurel_uncensored] log_B_obs_jurel     = log(B_obs_jurel);
  real log_B_censor_limit_jurel = log(B_censor_limit_jurel);
}

parameters {
  // ------ Parámetros estructurales por stock (log-escala, non-centered) ------
  vector[S] z_log_r;         // N(0,1); log_r = log_r_prior_mean + z*log_r_prior_sd
  vector[S] z_log_K;
  vector[S] z_log_B0;

  // ------ Shifters ambientales (por stock, no jerárquico) ------
  vector[S] rho_sst;
  vector[S] rho_chl;

  // ------ Ruido de proceso ------
  vector<lower=0>[S] sigma_proc;
  cholesky_factor_corr[S] L_Omega;        // LKJ cholesky de la correlación

  // ------ Ruido de observación ------
  vector<lower=0>[S] sigma_obs;

  // ------ Estado latente (log-biomasa) ------
  // Parametrización non-centered: z_B matriz T×S, luego se transforma.
  matrix[T, S] z_B;                        // N(0,1), innovaciones estandarizadas
}

transformed parameters {
  // ------ Destransformar parámetros log-escala ------
  vector[S] log_r  = log_r_prior_mean  + z_log_r  .* log_r_prior_sd;
  vector[S] log_K  = log_K_prior_mean  + z_log_K  .* log_K_prior_sd;
  vector[S] log_B0 = log_B0_prior_mean + z_log_B0 .* log_B0_prior_sd;
  vector<lower=0>[S] r_ = exp(log_r);     // _ para no colisionar con nombre matemático

  // ------ Propagación del estado latente (log-escala) ------
  // logB[t, s] = mean_from_schaefer_{t-1,s} + innovacion_{t,s}
  // donde innovacion = sigma_proc .* (L_Omega * z_B[t,])
  matrix[T, S] logB;
  {
    matrix[S, S] L_proc = diag_pre_multiply(sigma_proc, L_Omega);

    // Año 1: condición inicial con innovación
    for (s in 1:S) {
      logB[1, s] = log_B0[s] + sigma_proc[s] * z_B[1, s];  // sin correlación en el primer paso
    }

    // Años 2..T
    for (t in 2:T) {
      // Calcular mean determinística por stock
      vector[S] logB_mean;
      for (s in 1:S) {
        real r_t = r_[s] * exp(rho_sst[s] * SST_c[t - 1] + rho_chl[s] * logCHL_c[t - 1]);
        logB_mean[s] = schaefer_step_log(logB[t - 1, s], log_K[s], r_t, C[t - 1, s]);
      }
      // Añadir innovación correlacionada multivariada
      vector[S] innov = L_proc * to_vector(z_B[t, ]);
      for (s in 1:S) {
        logB[t, s] = logB_mean[s] + innov[s];
      }
    }
  }
}

model {
  // -------------------- Priors --------------------
  // Log-escala non-centered (z ~ N(0,1) pull de priors informativos)
  z_log_r  ~ std_normal();
  z_log_K  ~ std_normal();
  z_log_B0 ~ std_normal();

  // Shifters: priors informativos stock-específicos (del stress test)
  for (s in 1:S) {
    rho_sst[s] ~ normal(rho_sst_prior_mean[s], rho_sst_prior_sd[s]);
    rho_chl[s] ~ normal(rho_chl_prior_mean[s], rho_chl_prior_sd[s]);
  }

  // Ruido de proceso
  sigma_proc ~ normal(sigma_proc_prior_mean, sigma_proc_prior_sd);
  L_Omega ~ lkj_corr_cholesky(2);

  // Ruido de observación (por stock)
  for (s in 1:S) {
    sigma_obs[s] ~ normal(sigma_obs_prior_mean[s], sigma_obs_prior_sd[s]);
  }

  // Innovaciones estandarizadas (non-centered)
  to_vector(z_B) ~ std_normal();

  // -------------------- Likelihood --------------------
  // Anchoveta: log-normal estándar
  for (n in 1:N_obs_anchoveta) {
    log_B_obs_anchoveta[n] ~ normal(logB[t_anchoveta[n], IDX_ANCH], sigma_obs[IDX_ANCH]);
  }
  // Sardina: log-normal estándar
  for (n in 1:N_obs_sardina) {
    log_B_obs_sardina[n] ~ normal(logB[t_sardina[n], IDX_SARD], sigma_obs[IDX_SARD]);
  }
  // Jurel uncensored: log-normal estándar
  for (n in 1:N_obs_jurel_uncensored) {
    log_B_obs_jurel[n] ~ normal(logB[t_jurel_unc[n], IDX_JUR], sigma_obs[IDX_JUR]);
  }
  // Jurel left-censored: P(obs <= limit) = Phi((log_limit - mu) / sigma)
  for (n in 1:N_obs_jurel_censored) {
    target += normal_lcdf(
      log_B_censor_limit_jurel |
      logB[t_jurel_cen[n], IDX_JUR], sigma_obs[IDX_JUR]
    );
  }
}

generated quantities {
  // ------ Parámetros en escala natural (para reportar) ------
  vector<lower=0>[S] r_nat = r_;
  vector<lower=0>[S] K_nat = exp(log_K);
  vector<lower=0>[S] B0_nat = exp(log_B0);

  // ------ Correlación cruzada de ruido de proceso ------
  corr_matrix[S] Omega = multiply_lower_tri_self_transpose(L_Omega);

  // ------ Estados suavizados (posterior predictive) ------
  matrix<lower=0>[T, S] B_smooth;
  for (t in 1:T) {
    for (s in 1:S) {
      B_smooth[t, s] = exp(logB[t, s]);
    }
  }

  // ------ Log-likelihood pointwise (para LOO-CV) ------
  int N_obs_total = N_obs_anchoveta + N_obs_sardina + N_obs_jurel_uncensored + N_obs_jurel_censored;
  vector[N_obs_total] log_lik;
  {
    int pos = 1;
    for (n in 1:N_obs_anchoveta) {
      log_lik[pos] = normal_lpdf(log_B_obs_anchoveta[n] | logB[t_anchoveta[n], IDX_ANCH], sigma_obs[IDX_ANCH]);
      pos += 1;
    }
    for (n in 1:N_obs_sardina) {
      log_lik[pos] = normal_lpdf(log_B_obs_sardina[n] | logB[t_sardina[n], IDX_SARD], sigma_obs[IDX_SARD]);
      pos += 1;
    }
    for (n in 1:N_obs_jurel_uncensored) {
      log_lik[pos] = normal_lpdf(log_B_obs_jurel[n] | logB[t_jurel_unc[n], IDX_JUR], sigma_obs[IDX_JUR]);
      pos += 1;
    }
    for (n in 1:N_obs_jurel_censored) {
      log_lik[pos] = normal_lcdf(log_B_censor_limit_jurel | logB[t_jurel_cen[n], IDX_JUR], sigma_obs[IDX_JUR]);
      pos += 1;
    }
  }

  // ------ Posterior predictive replicates (para ppc) ------
  // Replicas para cada observación, útil en posterior predictive checks del Rmd.
  vector<lower=0>[N_obs_anchoveta]        B_rep_anchoveta;
  vector<lower=0>[N_obs_sardina]          B_rep_sardina;
  vector<lower=0>[N_obs_jurel_uncensored] B_rep_jurel;
  for (n in 1:N_obs_anchoveta)
    B_rep_anchoveta[n] = exp(normal_rng(logB[t_anchoveta[n], IDX_ANCH], sigma_obs[IDX_ANCH]));
  for (n in 1:N_obs_sardina)
    B_rep_sardina[n] = exp(normal_rng(logB[t_sardina[n], IDX_SARD], sigma_obs[IDX_SARD]));
  for (n in 1:N_obs_jurel_uncensored)
    B_rep_jurel[n] = exp(normal_rng(logB[t_jurel_unc[n], IDX_JUR], sigma_obs[IDX_JUR]));
}
