// =============================================================================
// paper1/stan/t4b_state_space_ind.stan
//
// T4b paso 6(b) -- 3 stocks INDEPENDIENTES (Omega = I).
// Generalizacion multi-stock del modelo T4b single-species validado en 6(a).
//
// Arquitectura (hereda de t4b_state_space_single.stan, version centered):
//   - CENTERED parametrization del estado latente logB (matrix[T, S])
//   - NON-CENTERED para parametros estructurales (z_log_r, z_log_K, z_log_B0)
//   - Priors apretados por stock (sd en log-escala como input del runner)
//   - sigma_proc ~ lognormal (corta masa en cero, evita funnel)
//   - sigma_obs  ~ normal (truncada por <lower=0>)
//   - SIN correlacion cruzada entre stocks (equivalente a Omega = I_S)
//   - SIN shifters ambientales (rho_SST = rho_CHL = 0 implicito)
//
// Estructura de observaciones (identica al T4 v1 original):
//   - anchoveta_cs  : SSB SCAA IFOP 2000-2024 (pero usando biomass_total_t)
//   - sardina_cs    : biomass_total_t IFOP 2000-2024
//   - jurel_cs      : biomasa acustica con gaps MAR + 2 obs left-censored
//                     (2012: 2.547 mil t, 2015: 0 mil t -> tratadas como <= 3 mil t)
//
// Escalado esperado: con ~80 obs totales y ~90 parametros libres (3r + 3K +
// 3B0 + 3sigma_obs + 3sigma_proc + 75 estados), T4b-ind deberia converger
// en 2-10 segundos con 8 chains. Si no converge con R-hat<=1.01 y 0
// divergences, el problema es la correlacion cruzada pending o la obs
// heterogenea de jurel -- revisar caso por caso antes de agregar Omega.
// =============================================================================

functions {
  real schaefer_step_log(real logB, real logK, real r_t, real C) {
    real B   = exp(logB);
    real K   = exp(logK);
    real g   = r_t * B * (1.0 - B / K);
    real B1  = B + g - C;
    real floor_ = 0.01 * K;
    return log(fmax(floor_, B1));
  }
}

data {
  int<lower=1> S;                          // 3 stocks
  int<lower=1> T;                          // 25 anios
  int<lower=1> N_obs_anch;
  int<lower=1> N_obs_sard;
  int<lower=1> N_obs_jur_unc;
  int<lower=0> N_obs_jur_cen;

  // Indices temporales por stock
  array[N_obs_anch]    int<lower=1, upper=T> t_anch;
  array[N_obs_sard]    int<lower=1, upper=T> t_sard;
  array[N_obs_jur_unc] int<lower=1, upper=T> t_jur_unc;
  array[N_obs_jur_cen] int<lower=1, upper=T> t_jur_cen;

  // Observaciones
  vector<lower=0>[N_obs_anch]    B_obs_anch;
  vector<lower=0>[N_obs_sard]    B_obs_sard;
  vector<lower=0>[N_obs_jur_unc] B_obs_jur;
  real<lower=0> B_censor_limit_jurel;      // e.g. 3 mil t

  // Captura: col 1=anch, 2=sard, 3=jur
  matrix<lower=0>[T, S] C;

  // Priors por stock (todos en log-escala)
  vector[S] log_r_prior_mean;
  vector<lower=0>[S] log_r_prior_sd;
  vector[S] log_K_prior_mean;
  vector<lower=0>[S] log_K_prior_sd;
  vector[S] log_B0_prior_mean;
  vector<lower=0>[S] log_B0_prior_sd;

  // Ruido de observacion (normal truncada)
  vector<lower=0>[S] sigma_obs_prior_mean;
  vector<lower=0>[S] sigma_obs_prior_sd;

  // Ruido de proceso (lognormal -- corta masa en cero)
  vector[S] sigma_proc_prior_logmean;
  vector<lower=0>[S] sigma_proc_prior_logsd;
}

transformed data {
  int IDX_ANCH = 1;
  int IDX_SARD = 2;
  int IDX_JUR  = 3;

  vector[N_obs_anch]    log_B_obs_anch = log(B_obs_anch);
  vector[N_obs_sard]    log_B_obs_sard = log(B_obs_sard);
  vector[N_obs_jur_unc] log_B_obs_jur  = log(B_obs_jur);
  real log_B_censor_limit_jurel        = log(B_censor_limit_jurel);

  int N_obs_total = N_obs_anch + N_obs_sard + N_obs_jur_unc + N_obs_jur_cen;
}

parameters {
  vector[S] z_log_r;
  vector[S] z_log_K;
  vector[S] z_log_B0;

  vector<lower=0>[S] sigma_proc;
  vector<lower=0>[S] sigma_obs;

  matrix[T, S] logB;                       // estado latente CENTERED
}

transformed parameters {
  vector[S] log_r  = log_r_prior_mean  + z_log_r  .* log_r_prior_sd;
  vector[S] log_K  = log_K_prior_mean  + z_log_K  .* log_K_prior_sd;
  vector[S] log_B0 = log_B0_prior_mean + z_log_B0 .* log_B0_prior_sd;
  vector<lower=0>[S] r_ = exp(log_r);
}

model {
  // ---- Priors estructurales ----
  z_log_r  ~ std_normal();
  z_log_K  ~ std_normal();
  z_log_B0 ~ std_normal();

  // ---- Priors ruido (vectorizados por stock) ----
  for (s in 1:S) {
    sigma_proc[s] ~ lognormal(sigma_proc_prior_logmean[s], sigma_proc_prior_logsd[s]);
    sigma_obs[s]  ~ normal(sigma_obs_prior_mean[s], sigma_obs_prior_sd[s]);
  }

  // ---- Dinamica por stock (CENTERED, independiente) ----
  for (s in 1:S) {
    logB[1, s] ~ normal(log_B0[s], sigma_proc[s]);
    for (t in 2:T) {
      real logB_mean = schaefer_step_log(logB[t - 1, s], log_K[s], r_[s], C[t - 1, s]);
      logB[t, s] ~ normal(logB_mean, sigma_proc[s]);
    }
  }

  // ---- Likelihood ----
  // Anchoveta y sardina: log-normal estandar
  for (n in 1:N_obs_anch) {
    log_B_obs_anch[n] ~ normal(logB[t_anch[n], IDX_ANCH], sigma_obs[IDX_ANCH]);
  }
  for (n in 1:N_obs_sard) {
    log_B_obs_sard[n] ~ normal(logB[t_sard[n], IDX_SARD], sigma_obs[IDX_SARD]);
  }
  // Jurel uncensored
  for (n in 1:N_obs_jur_unc) {
    log_B_obs_jur[n] ~ normal(logB[t_jur_unc[n], IDX_JUR], sigma_obs[IDX_JUR]);
  }
  // Jurel left-censored: P(obs <= limit) = Phi((log_limit - mu) / sigma)
  for (n in 1:N_obs_jur_cen) {
    target += normal_lcdf(
      log_B_censor_limit_jurel |
      logB[t_jur_cen[n], IDX_JUR], sigma_obs[IDX_JUR]
    );
  }
}

generated quantities {
  vector<lower=0>[S] r_nat  = r_;
  vector<lower=0>[S] K_nat  = exp(log_K);
  vector<lower=0>[S] B0_nat = exp(log_B0);

  matrix<lower=0>[T, S] B_smooth;
  for (t in 1:T) for (s in 1:S) B_smooth[t, s] = exp(logB[t, s]);

  vector[N_obs_total] log_lik;
  {
    int pos = 1;
    for (n in 1:N_obs_anch) {
      log_lik[pos] = normal_lpdf(log_B_obs_anch[n] |
                                 logB[t_anch[n], IDX_ANCH], sigma_obs[IDX_ANCH]);
      pos += 1;
    }
    for (n in 1:N_obs_sard) {
      log_lik[pos] = normal_lpdf(log_B_obs_sard[n] |
                                 logB[t_sard[n], IDX_SARD], sigma_obs[IDX_SARD]);
      pos += 1;
    }
    for (n in 1:N_obs_jur_unc) {
      log_lik[pos] = normal_lpdf(log_B_obs_jur[n] |
                                 logB[t_jur_unc[n], IDX_JUR], sigma_obs[IDX_JUR]);
      pos += 1;
    }
    for (n in 1:N_obs_jur_cen) {
      log_lik[pos] = normal_lcdf(log_B_censor_limit_jurel |
                                 logB[t_jur_cen[n], IDX_JUR], sigma_obs[IDX_JUR]);
      pos += 1;
    }
  }

  // Replicas para PPC
  vector<lower=0>[N_obs_anch]    B_rep_anch;
  vector<lower=0>[N_obs_sard]    B_rep_sard;
  vector<lower=0>[N_obs_jur_unc] B_rep_jur;
  for (n in 1:N_obs_anch)
    B_rep_anch[n] = exp(normal_rng(logB[t_anch[n], IDX_ANCH], sigma_obs[IDX_ANCH]));
  for (n in 1:N_obs_sard)
    B_rep_sard[n] = exp(normal_rng(logB[t_sard[n], IDX_SARD], sigma_obs[IDX_SARD]));
  for (n in 1:N_obs_jur_unc)
    B_rep_jur[n]  = exp(normal_rng(logB[t_jur_unc[n], IDX_JUR], sigma_obs[IDX_JUR]));
}
