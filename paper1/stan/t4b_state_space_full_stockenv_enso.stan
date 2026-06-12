// =============================================================================
// paper1/stan/t4b_state_space_full_stockenv_enso.stan
//
// Variante del t4b_state_space_full_stockenv.stan que incorpora un tercer
// shifter climatico basin-scale: el indice ENSO Nino 3.4. Usado para el
// pivote 2026-05-04 del paper 1 (project_paper1_enso_pivot).
//
// Motivacion: el Apendice E muestra que jurel CS no identifica los shifters
// costeros (SST_D1, logCHL_D1; sigma_post/sigma_prior ~ 1.0 a traves de tres
// dominios espaciales D1/D2/D3). El feedback de un colega 2026-05-04 cerro
// que el null es defendible econometricamente pero no como "el clima no
// afecta al jurel" para policy. Existing literatura (Arcos2001, Pena-Torres2017,
// Espinoza2013) documenta efectos climaticos sobre jurel a escala basin-scale
// vias teleconexiones ENSO. Este modelo testea esa hipotesis.
//
// Diferencia con t4b_state_space_full_stockenv.stan:
//   - Agrega data: vector[T] ENSO_c (indice Nino 3.4 anual centrado, basin-scale,
//     UN solo time series visible por todos los stocks; el efecto stock-specific
//     viene de rho_enso[s]).
//   - Agrega parameter: vector[S] rho_enso con prior stock-especifico.
//   - Dinamica: r_t[s] = r_base[s] * exp(rho_sst[s] * SST_c[t-1, s]
//                                      + rho_chl[s] * logCHL_c[t-1, s]
//                                      + rho_enso[s] * ENSO_c[t-1])
//
// Mecanismo para "apagar" shifters por stock via priors YAML:
//   - Para jurel: rho_enso[3] activo (prior N(0, 0.5)); rho_sst[3] y rho_chl[3]
//     pinned a 0 con prior tight (N(0, 0.01)) -- jurel solo "ve" ENSO.
//   - Para anch/sard: rho_sst[s] y rho_chl[s] como antes (priors normales);
//     rho_enso[s] pinned a 0 con prior tight (N(0, 0.01)) -- no ven ENSO.
// Los priors son responsables de mantener la convencion "cada stock ve solo
// los shifters que le corresponden". El R wrapper escribe los priors YAML
// apropiados.
//
// Si rho_enso es N(0, 0.01) para los tres stocks Y ENSO_c es vector de ceros,
// este modelo es matematicamente equivalente al stockenv original.
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
  int<lower=1> S;
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

  matrix<lower=0>[T, S] C;

  matrix[T, S] SST_c;          // SST anomalia centrada (degC) por stock
  matrix[T, S] logCHL_c;       // log(CHL) centrada por stock
  vector[T]    ENSO_c;         // ENSO Nino 3.4 anomalia centrada (degC) -- basin-scale, comun a todos los stocks

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

  vector[S] rho_sst_prior_mean;
  vector<lower=0>[S] rho_sst_prior_sd;
  vector[S] rho_chl_prior_mean;
  vector<lower=0>[S] rho_chl_prior_sd;
  vector[S] rho_enso_prior_mean;          // NUEVO
  vector<lower=0>[S] rho_enso_prior_sd;   // NUEVO
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

  cholesky_factor_corr[S] L_Omega;

  vector[S] rho_sst;
  vector[S] rho_chl;
  vector[S] rho_enso;       // NUEVO

  array[T] vector[S] logB;
}

transformed parameters {
  vector[S] log_r  = log_r_prior_mean  + z_log_r  .* log_r_prior_sd;
  vector[S] log_K  = log_K_prior_mean  + z_log_K  .* log_K_prior_sd;
  vector[S] log_B0 = log_B0_prior_mean + z_log_B0 .* log_B0_prior_sd;
  vector<lower=0>[S] r_base = exp(log_r);
}

model {
  // Priors estructurales
  z_log_r  ~ std_normal();
  z_log_K  ~ std_normal();
  z_log_B0 ~ std_normal();

  // Priors ruido
  for (s in 1:S) {
    sigma_proc[s] ~ lognormal(sigma_proc_prior_logmean[s], sigma_proc_prior_logsd[s]);
    sigma_obs[s]  ~ normal(sigma_obs_prior_mean[s], sigma_obs_prior_sd[s]);
  }

  // Prior LKJ
  L_Omega ~ lkj_corr_cholesky(4);

  // Priors shifters (stock-especificos)
  for (s in 1:S) {
    rho_sst[s]  ~ normal(rho_sst_prior_mean[s],  rho_sst_prior_sd[s]);
    rho_chl[s]  ~ normal(rho_chl_prior_mean[s],  rho_chl_prior_sd[s]);
    rho_enso[s] ~ normal(rho_enso_prior_mean[s], rho_enso_prior_sd[s]);  // NUEVO
  }

  // Dinamica multivariada con shifters ambientales STOCK-ESPECIFICOS + ENSO basin-scale
  {
    matrix[S, S] L_proc = diag_pre_multiply(sigma_proc, L_Omega);

    for (s in 1:S) {
      logB[1][s] ~ normal(log_B0[s], sigma_proc[s]);
    }

    for (t in 2:T) {
      vector[S] logB_mean_t;
      for (s in 1:S) {
        // CAMBIO: agrega rho_enso[s] * ENSO_c[t-1] al exponente de r_t
        real r_t = r_base[s]
                   * exp(rho_sst[s]  * SST_c[t - 1, s]
                       + rho_chl[s]  * logCHL_c[t - 1, s]
                       + rho_enso[s] * ENSO_c[t - 1]);
        logB_mean_t[s] = schaefer_step_log(logB[t - 1][s], log_K[s], r_t, C[t - 1, s]);
      }
      logB[t] ~ multi_normal_cholesky(logB_mean_t, L_proc);
    }
  }

  // Likelihood
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
}

generated quantities {
  vector<lower=0>[S] r_nat   = r_base;
  vector<lower=0>[S] K_nat   = exp(log_K);
  vector<lower=0>[S] B0_nat  = exp(log_B0);

  corr_matrix[S] Omega = multiply_lower_tri_self_transpose(L_Omega);

  matrix<lower=0>[T, S] B_smooth;
  for (t in 1:T) for (s in 1:S) B_smooth[t, s] = exp(logB[t][s]);

  matrix<lower=0>[T - 1, S] r_eff;
  for (t in 2:T) for (s in 1:S) {
    // CAMBIO: agrega rho_enso[s] * ENSO_c[t-1]
    r_eff[t - 1, s] = r_base[s]
                      * exp(rho_sst[s]  * SST_c[t - 1, s]
                          + rho_chl[s]  * logCHL_c[t - 1, s]
                          + rho_enso[s] * ENSO_c[t - 1]);
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
  }

  vector<lower=0>[N_obs_anch]    B_rep_anch;
  vector<lower=0>[N_obs_sard]    B_rep_sard;
  vector<lower=0>[N_obs_jur_unc] B_rep_jur;
  for (n in 1:N_obs_anch)
    B_rep_anch[n] = exp(normal_rng(logB[t_anch[n]][IDX_ANCH], sigma_obs[IDX_ANCH]));
  for (n in 1:N_obs_sard)
    B_rep_sard[n] = exp(normal_rng(logB[t_sard[n]][IDX_SARD], sigma_obs[IDX_SARD]));
  for (n in 1:N_obs_jur_unc)
    B_rep_jur[n]  = exp(normal_rng(logB[t_jur_unc[n]][IDX_JUR], sigma_obs[IDX_JUR]));
}
