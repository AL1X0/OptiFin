#ifndef RUNNER_CRASH_REPORT_H_
#define RUNNER_CRASH_REPORT_H_

// Plantage natif (lecteur vidéo, pilote graphique…) : le module fautif et l'adresse sont
// ajoutés au journal d'OptiFin (%APPDATA%\app.optifin\optifin\optifin.log, lu au lancement
// suivant), avec un petit fichier crash.dmp à côté pour l'analyse.
void InstallCrashReport();

#endif  // RUNNER_CRASH_REPORT_H_
