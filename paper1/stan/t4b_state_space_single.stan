// =============================================================================
// paper1/stan/t4b_state_space_single.stan
//
// T4b paso 6(a) -- Single-species Schaefer state-space Bayesiano.
// Version 2026-04-23 (b): CENTERED parametrization del estado latente.
//
// CAMBIOS respecto a la version anterior (non-centered z_B):
//   - Estado latente logB ahora es parametro DIRECTO (sin z_B).
//     Motivacion: cuando sigma_proc es pequeno (posterior median ~0.22),
//     la parametrizacion non-centered produce funnel clasico de Neal entre
//     log(sigma_proc) y z_B, y HMC genera divergencias (15% en el fit previo).
//     Con 25 obs informativas sobre cada logB[t], centered mixea mejor
//     (Betancourt & Girolami 2015).
//   - Prior de sigma_proc cambiado de half-normal(0, sd) a lognormal(logmean,
//     logsd). La lognormal pone masa 0 en sigma_proc=0, cerrando la region
//     patologica que activaba el funnel.
//   - r, K, B0 siguen non-centered con sus z's (priors informativos apretados,
//     no generan funnel porque no hay sigma multiplicando).
//
// Inputs (ver runner 02_fit_t4b_single_anchoveta.R):
//   log_*_prior_mean, log_*_prior_sd     para r, K, B0 (como antes)
//   sigma_obs_prior_mean, sigma_obs_prior_sd         (normal, como antes)
//   sigma_proc_prior_logmean, sigma_proc_prior_logsd  (lognormal, NUEVO)
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
  int<lower=1> T;
  int<lower=1> N_obs;
  array[N_obs] int<lower=1, upper=T> t_obs;
  vector<lower=0>[N_obs] B_obs;            // mil t (biomass_total)
  vector<lower=0>[T] C;                    // captura mil t/anio

  real log_r_prior_mean;
  real<lower=0> log_r_prior_sd;
  real log_K_prior_mean;
  real<lower=0> log_K_prior_sd;
  real log_B0_prior_mean;
  real<lower=0> log_B0_prior_sd;

  real<lower=0> sigma_obs_prior_mean;
  real<lower=0> sigma_obs_prior_sd;

  real sigma_proc_prior_logmean;           // e.g. log(0.10) = -2.30
  real<lower=0> sigma_proc_prior_logsd;    // e.g. 0.40
}

transformed data {
  vector[N_obs] log_B_obs = log(B_obs);
}

parameters {
  // Non-centered para parametros estructurales (funcionan bien con priors
  // informativos; no hay funnel porque no multiplican a un estado latente).
  real z_log_r;
  real z_log_K;
  real z_log_B0;

  real<lower=0> sigma_proc;
  real<lower=0> sigma_obs;

  // CENTERED: estado latente directo, sin z_B. Cambio clave vs version previa.
  vector[T] logB;
}

transformed parameters {
  real log_r  = log_r_prior_mean  + z_log_r  * log_r_prior_sd;
  real log_K  = log_K_prior_mean  + z_log_K  * log_K_prior_sd;
  real log_B0 = log_B0_prior_mean + z_log_B0 * log_B0_prior_sd;
  real r_nat_ = exp(log_r);
}

model {
  // ---- Priors en parametros estructurales ----
  z_log_r  ~ std_normal();
  z_log_K  ~ std_normal();
  z_log_B0 ~ std_normal();

  // ---- Priors en ruido ----
  // sigma_proc: lognormal corta la masa en cero (evita funnel).
  sigma_proc ~ lognormal(sigma_proc_prior_logmean, sigma_proc_prior_logsd);
  // sigma_obs: normal truncada (por <lower=0>).
  sigma_obs  ~ normal(sigma_obs_prior_mean, sigma_obs_prior_sd);

  // ---- Dinamica del estado latente (CENTERED) ----
  // Ano 1: ruido proceso alrededor de B0
  logB[1] ~ normal(log_B0, sigma_proc);
  // Anos 2..T: Schaefer deterministico + ruido proceso
  for (t in 2:T) {
    real logB_mean = schaefer_step_log(logB[t - 1], log_K, r_nat_, C[t - 1]);
    logB[t] ~ normal(logB_mean, sigma_proc);
  }

  // ---- Likelihood ----
  for (n in 1:N_obs) {
    log_B_obs[n] ~ normal(logB[t_obs[n]], sigma_obs);
  }
}

generated quantities {
  real r_nat  = exp(log_r);
  real K_nat  = exp(log_K);
  real B0_nat = exp(log_B0);

  vector<lower=0>[T] B_smooth;
  for (t in 1:T) B_smooth[t] = exp(logB[t]);

  vector[N_obs] log_lik;
  vector<lower=0>[N_obs] B_rep;
  for (n in 1:N_obs) {
    log_lik[n] = normal_lpdf(log_B_obs[n] | logB[t_obs[n]], sigma_obs);
    B_rep[n]   = exp(normal_rng(logB[t_obs[n]], sigma_obs));
  }
}
