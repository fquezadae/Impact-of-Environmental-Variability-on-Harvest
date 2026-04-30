// =============================================================================
// paper1/stan/t4b_state_space_full_dualjurel.stan
//
// T4b paso 6(d) -- VARIANTE DUAL-JUREL (item #10, 2026-04-30 PM tarde).
// Extiende t4b_state_space_full.stan agregando un SEGUNDO STATE para jurel
// (Norte chileno acustico) que comparte los shifters climaticos rho_sst[IDX_JUR]
// y rho_chl[IDX_JUR] con el state CS.
//
// Motivacion: jurel CS esta no-identificado en t4b_state_space_full.stan
// (sigma_post/sigma_prior ~ 1 across los 3 dominios del Apendice E). La serie
// acustica jurel Norte chileno (RECLAS Norte, IFOP) muestra correlacion log
// = 0.88 con la serie CS sobre 7 anios solapados (2010-2023), consistente con
// jurel siendo un solo stock biologico range-wide observado desde dos ventanas
// espaciales chilenas. Imponer rho_jur comun entre los dos states amortigua la
// info climatica del stock y deberia rescatar la identificacion.
//
// IMPORTANTE: la proyeccion del paper sigue usando ESTADO CS (no Norte). El
// state Norte solo aporta likelihood adicional para identificar rho_jur. r y K
// del state Norte son parametros independientes (cada region tiene sus
// niveles); solo rho_jur es compartido.
//
// Version primary (sin Norte): t4b_state_space_full.stan. Esta version se usa
// SOLO para item #10 sanity check; si identifica, se promueve a primary.
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
  int<lower=1> S;                  // 3 stocks CS: anch, sard, jur (CS)
  int<lower=1> T;
  int<lower=1> N_obs_anch;
  int<lower=1> N_obs_sard;
  int<lower=1> N_obs_jur_unc;
  int<lower=0> N_obs_jur_cen;

  array[N_obs_anch]    int<lower=1, upper=T> t_anch;
  array[N_obs_sard]    int<lower=1, upper=T> t_sard;
  array[N_obs_jur_unc] int<lower=1, upper=T> t_jur_unc;
  array[N_obs_jur_cen] int<lower=1, upper=T> t_jur_cen;

  vector<lower=0>[N_obs_anch]    B_obs_anch;
  vector<lower=0>[N_obs_sard]    B_obs_sard;
  vector<lower=0>[N_obs_jur_unc] B_obs_jur;
  real<lower=0> B_censor_limit_jurel;

  matrix<lower=0>[T, S] C;         // captura CS (anch, sard, jur)

  // Env CS (D1 centro_sur_eez): para los 3 stocks CS
  vector[T] SST_c;
  vector[T] logCHL_c;

  // ---------- DUAL JUREL: state Norte chileno ----------
  int<lower=0> N_obs_jur_norte;
  array[N_obs_jur_norte] int<lower=1, upper=T> t_jur_norte;
  vector<lower=0>[N_obs_jur_norte] B_obs_jur_norte;

  // Captura jurel Norte por anio (input opcional; si no se tiene, pasar 0
  // para todos los t y reportar como caveat -- el state evoluciona libremente
  // bajo Schaefer sin extraccion). En la practica para item #10 podemos pasar
  // capture jurel Norte total chileno (DESEMBARCO IFOP zona norte).
  vector<lower=0>[T] C_jur_norte;

  // Env Norte chileno (D4 norte_chile_eez, lat -30 a -18, lon -75 a -65):
  // construido por R/06_projections/06_extended_env_anomalies.R con el dominio
  // norte_chile_eez agregado 2026-04-30 PM tarde.
  vector[T] SST_c_norte;
  vector[T] logCHL_c_norte;

  // Priors r/K/B0 para state Norte. Por default usar los mismos del jurel CS,
  // o levemente mas amplios para reflejar incertidumbre extra.
  real log_r_jur_norte_prior_mean;
  real<lower=0> log_r_jur_norte_prior_sd;
  real log_K_jur_norte_prior_mean;
  real<lower=0> log_K_jur_norte_prior_sd;
  real log_B0_jur_norte_prior_mean;
  real<lower=0> log_B0_jur_norte_prior_sd;

  real<lower=0> sigma_obs_jur_norte_prior_mean;
  real<lower=0> sigma_obs_jur_norte_prior_sd;
  real sigma_proc_jur_norte_prior_logmean;
  real<lower=0> sigma_proc_jur_norte_prior_logsd;
  // ---------- /DUAL JUREL ----------

  vector[S] log_r_prior_mean;
  vector<lower=0>[S] log_r_prior_sd;
  vector[S] log_K_prior_mean;
  vector<lower=0>[S] log_K_prior_sd;
  vector[S] log_B0_prior_mean;
  vector<lower=0>[S] log_B0_prior_sd;

  vector<lower=0>[S] sigma_obs_prior_mean;
  vector<lower=0>[S] sigma_obs_prior_sd;

  vector[S] sigma_proc_prior_logmean;
  vector<lower=0>[S] sigma_proc_prior_logsd;

  // Priors stock-especificos para shifters (jurel CS y Norte comparten
  // rho_sst[IDX_JUR] y rho_chl[IDX_JUR]; los priors aqui son para CS y se
  // aplican simultaneamente a ambos states).
  vector[S] rho_sst_prior_mean;
  vector<lower=0>[S] rho_sst_prior_sd;
  vector[S] rho_chl_prior_mean;
  vector<lower=0>[S] rho_chl_prior_sd;
}

transformed data {
  int IDX_ANCH = 1;
  int IDX_SARD = 2;
  int IDX_JUR  = 3;

  vector[N_obs_anch]    log_B_obs_anch      = log(B_obs_anch);
  vector[N_obs_sard]    log_B_obs_sard      = log(B_obs_sard);
  vector[N_obs_jur_unc] log_B_obs_jur       = log(B_obs_jur);
  vector[N_obs_jur_norte] log_B_obs_jur_norte = log(B_obs_jur_norte);
  real log_B_censor_limit_jurel             = log(B_censor_limit_jurel);

  int N_obs_total = N_obs_anch + N_obs_sard + N_obs_jur_unc + N_obs_jur_cen
                    + N_obs_jur_norte;
}

parameters {
  vector[S] z_log_r;
  vector[S] z_log_K;
  vector[S] z_log_B0;

  vector<lower=0>[S] sigma_proc;
  vector<lower=0>[S] sigma_obs;

  cholesky_factor_corr[S] L_Omega;

  vector[S] rho_sst;
  vector[S] rho_chl;

  array[T] vector[S] logB;

  // ---------- DUAL JUREL: state Norte chileno (independiente del LKJ S=3) ----
  real z_log_r_jur_norte;
  real z_log_K_jur_norte;
  real z_log_B0_jur_norte;
  real<lower=0> sigma_proc_jur_norte;
  real<lower=0> sigma_obs_jur_norte;
  vector[T] logB_jur_norte;
  // ---------- /DUAL JUREL ----------
}

transformed parameters {
  vector[S] log_r  = log_r_prior_mean  + z_log_r  .* log_r_prior_sd;
  vector[S] log_K  = log_K_prior_mean  + z_log_K  .* log_K_prior_sd;
  vector[S] log_B0 = log_B0_prior_mean + z_log_B0 .* log_B0_prior_sd;
  vector<lower=0>[S] r_base = exp(log_r);

  // Norte
  real log_r_jur_norte  = log_r_jur_norte_prior_mean
                          + z_log_r_jur_norte * log_r_jur_norte_prior_sd;
  real log_K_jur_norte  = log_K_jur_norte_prior_mean
                          + z_log_K_jur_norte * log_K_jur_norte_prior_sd;
  real log_B0_jur_norte = log_B0_jur_norte_prior_mean
                          + z_log_B0_jur_norte * log_B0_jur_norte_prior_sd;
  real<lower=0> r_base_jur_norte = exp(log_r_jur_norte);
}

model {
  // Priors estructurales CS
  z_log_r  ~ std_normal();
  z_log_K  ~ std_normal();
  z_log_B0 ~ std_normal();

  for (s in 1:S) {
    sigma_proc[s] ~ lognormal(sigma_proc_prior_logmean[s], sigma_proc_prior_logsd[s]);
    sigma_obs[s]  ~ normal(sigma_obs_prior_mean[s], sigma_obs_prior_sd[s]);
  }

  L_Omega ~ lkj_corr_cholesky(4);

  // Priors shifters jurel (compartidos entre CS y Norte)
  for (s in 1:S) {
    rho_sst[s] ~ normal(rho_sst_prior_mean[s], rho_sst_prior_sd[s]);
    rho_chl[s] ~ normal(rho_chl_prior_mean[s], rho_chl_prior_sd[s]);
  }

  // Priors estructurales Norte
  z_log_r_jur_norte  ~ std_normal();
  z_log_K_jur_norte  ~ std_normal();
  z_log_B0_jur_norte ~ std_normal();
  sigma_proc_jur_norte ~ lognormal(sigma_proc_jur_norte_prior_logmean,
                                    sigma_proc_jur_norte_prior_logsd);
  sigma_obs_jur_norte  ~ normal(sigma_obs_jur_norte_prior_mean,
                                 sigma_obs_jur_norte_prior_sd);

  // -------- Dinamica multivariada CS (3 stocks correlacionados) --------
  {
    matrix[S, S] L_proc = diag_pre_multiply(sigma_proc, L_Omega);

    for (s in 1:S) {
      logB[1][s] ~ normal(log_B0[s], sigma_proc[s]);
    }

    for (t in 2:T) {
      vector[S] logB_mean_t;
      for (s in 1:S) {
        real r_t = r_base[s]
                   * exp(rho_sst[s] * SST_c[t - 1]
                       + rho_chl[s] * logCHL_c[t - 1]);
        logB_mean_t[s] = schaefer_step_log(logB[t - 1][s], log_K[s], r_t, C[t - 1, s]);
      }
      logB[t] ~ multi_normal_cholesky(logB_mean_t, L_proc);
    }
  }

  // -------- Dinamica univariada NORTE jurel (state independiente) --------
  // Comparte rho_sst[IDX_JUR] y rho_chl[IDX_JUR] con el state CS jurel.
  // Diferencias: env_c es el del dominio Norte (D4 norte_chile_eez), r_base
  // y K_nat son propios del Norte, captura es C_jur_norte[t].
  logB_jur_norte[1] ~ normal(log_B0_jur_norte, sigma_proc_jur_norte);

  for (t in 2:T) {
    real r_t_norte = r_base_jur_norte
                     * exp(rho_sst[IDX_JUR] * SST_c_norte[t - 1]
                         + rho_chl[IDX_JUR] * logCHL_c_norte[t - 1]);
    real logB_mean_norte_t = schaefer_step_log(logB_jur_norte[t - 1],
                                                log_K_jur_norte,
                                                r_t_norte,
                                                C_jur_norte[t - 1]);
    logB_jur_norte[t] ~ normal(logB_mean_norte_t, sigma_proc_jur_norte);
  }

  // -------- Likelihood CS --------
  for (n in 1:N_obs_anch) {
    log_B_obs_anch[n] ~ normal(logB[t_anch[n]][IDX_ANCH], sigma_obs[IDX_ANCH]);
  }
  for (n in 1:N_obs_sard) {
    log_B_obs_sard[n] ~ normal(logB[t_sard[n]][IDX_SARD], sigma_obs[IDX_SARD]);
  }
  for (n in 1:N_obs_jur_unc) {
    log_B_obs_jur[n] ~ normal(logB[t_jur_unc[n]][IDX_JUR], sigma_obs[IDX_JUR]);
  }
  for (n in 1:N_obs_jur_cen) {
    target += normal_lcdf(
      log_B_censor_limit_jurel |
      logB[t_jur_cen[n]][IDX_JUR], sigma_obs[IDX_JUR]
    );
  }

  // -------- Likelihood NORTE jurel --------
  for (n in 1:N_obs_jur_norte) {
    log_B_obs_jur_norte[n] ~ normal(logB_jur_norte[t_jur_norte[n]],
                                     sigma_obs_jur_norte);
  }
}

generated quantities {
  vector<lower=0>[S] r_nat   = r_base;
  vector<lower=0>[S] K_nat   = exp(log_K);
  vector<lower=0>[S] B0_nat  = exp(log_B0);

  real<lower=0> r_nat_jur_norte  = r_base_jur_norte;
  real<lower=0> K_nat_jur_norte  = exp(log_K_jur_norte);
  real<lower=0> B0_nat_jur_norte = exp(log_B0_jur_norte);

  corr_matrix[S] Omega = multiply_lower_tri_self_transpose(L_Omega);

  matrix<lower=0>[T, S] B_smooth;
  for (t in 1:T) for (s in 1:S) B_smooth[t, s] = exp(logB[t][s]);

  vector<lower=0>[T] B_smooth_jur_norte;
  for (t in 1:T) B_smooth_jur_norte[t] = exp(logB_jur_norte[t]);

  // r_t efectivo CS (3 stocks)
  matrix<lower=0>[T - 1, S] r_eff;
  for (t in 2:T) for (s in 1:S) {
    r_eff[t - 1, s] = r_base[s]
                      * exp(rho_sst[s] * SST_c[t - 1]
                          + rho_chl[s] * logCHL_c[t - 1]);
  }

  // r_t efectivo Norte jurel (con env_c_norte)
  vector<lower=0>[T - 1] r_eff_jur_norte;
  for (t in 2:T) {
    r_eff_jur_norte[t - 1] = r_base_jur_norte
                              * exp(rho_sst[IDX_JUR] * SST_c_norte[t - 1]
                                  + rho_chl[IDX_JUR] * logCHL_c_norte[t - 1]);
  }

  vector[N_obs_total] log_lik;
  {
    int pos = 1;
    for (n in 1:N_obs_anch) {
      log_lik[pos] = normal_lpdf(log_B_obs_anch[n] |
                                 logB[t_anch[n]][IDX_ANCH], sigma_obs[IDX_ANCH]);
      pos += 1;
    }
    for (n in 1:N_obs_sard) {
      log_lik[pos] = normal_lpdf(log_B_obs_sard[n] |
                                 logB[t_sard[n]][IDX_SARD], sigma_obs[IDX_SARD]);
      pos += 1;
    }
    for (n in 1:N_obs_jur_unc) {
      log_lik[pos] = normal_lpdf(log_B_obs_jur[n] |
                                 logB[t_jur_unc[n]][IDX_JUR], sigma_obs[IDX_JUR]);
      pos += 1;
    }
    for (n in 1:N_obs_jur_cen) {
      log_lik[pos] = normal_lcdf(log_B_censor_limit_jurel |
                                 logB[t_jur_cen[n]][IDX_JUR], sigma_obs[IDX_JUR]);
      pos += 1;
    }
    for (n in 1:N_obs_jur_norte) {
      log_lik[pos] = normal_lpdf(log_B_obs_jur_norte[n] |
                                 logB_jur_norte[t_jur_norte[n]],
                                 sigma_obs_jur_norte);
      pos += 1;
    }
  }

  vector<lower=0>[N_obs_anch]    B_rep_anch;
  vector<lower=0>[N_obs_sard]    B_rep_sard;
  vector<lower=0>[N_obs_jur_unc] B_rep_jur;
  vector<lower=0>[N_obs_jur_norte] B_rep_jur_norte;
  for (n in 1:N_obs_anch)
    B_rep_anch[n] = exp(normal_rng(logB[t_anch[n]][IDX_ANCH], sigma_obs[IDX_ANCH]));
  for (n in 1:N_obs_sard)
    B_rep_sard[n] = exp(normal_rng(logB[t_sard[n]][IDX_SARD], sigma_obs[IDX_SARD]));
  for (n in 1:N_obs_jur_unc)
    B_rep_jur[n]  = exp(normal_rng(logB[t_jur_unc[n]][IDX_JUR], sigma_obs[IDX_JUR]));
  for (n in 1:N_obs_jur_norte)
    B_rep_jur_norte[n] = exp(normal_rng(logB_jur_norte[t_jur_norte[n]],
                                         sigma_obs_jur_norte));
}
