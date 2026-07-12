export const CAMPAIGN_ACTS = [
  {
    ato: 1,
    slug: "VICE_AND_GLOW",
    nome: "Vice & Glow",
    regiao: "EUA - Miami & East Coast",
    enemyLevelRange: { min: 1, max: 5 },
    dropLevelRange: { min: 1, max: 5 },
    enemyBaseHealthRange: { min: 100, max: 180 },
    enemyBaseDamageRange: { min: 10, max: 18 },
    streets: [
      { ruaInicio: 1, ruaFim: 3, tema_geografico: "EUA - Avenidas Neon" },
      { ruaInicio: 4, ruaFim: 6, tema_geografico: "EUA - Pantanos Everglades" },
      { ruaInicio: 7, ruaFim: 10, tema_geografico: "EUA - Selva de Pedra NY" }
    ],
    boss: {
      rua: 11,
      nome: "Don da Costa Leste",
      vida: 500,
      dano: 35,
      tema_geografico: "EUA - Selva de Pedra NY"
    }
  },
  {
    ato: 2,
    slug: "O_CLA_NEON",
    nome: "O Cla Neon",
    regiao: "Japao - Yakuza",
    enemyLevelRange: { min: 6, max: 10 },
    dropLevelRange: { min: 6, max: 10 },
    enemyBaseHealthRange: { min: 220, max: 350 },
    enemyBaseDamageRange: { min: 22, max: 35 },
    streets: [
      { ruaInicio: 1, ruaFim: 3, tema_geografico: "Japao - Metropole Shinjuku" },
      { ruaInicio: 4, ruaFim: 6, tema_geografico: "Japao - Templos de Kyoto" },
      { ruaInicio: 7, ruaFim: 10, tema_geografico: "Japao - Porto de Osaka" }
    ],
    boss: {
      rua: 11,
      nome: "Oyabun",
      vida: 1000,
      dano: 60,
      tema_geografico: "Japao - Porto de Osaka"
    }
  },
  {
    ato: 3,
    slug: "TRIADE_IMPERIAL",
    nome: "Triade Imperial",
    regiao: "China - Hong Kong & Macau",
    enemyLevelRange: { min: 11, max: 15 },
    dropLevelRange: { min: 11, max: 15 },
    enemyBaseHealthRange: { min: 400, max: 650 },
    enemyBaseDamageRange: { min: 40, max: 65 },
    streets: [
      { ruaInicio: 1, ruaFim: 3, tema_geografico: "China - Mercados Flutuantes" },
      { ruaInicio: 4, ruaFim: 6, tema_geografico: "China - Cassinos de Macau" },
      { ruaInicio: 7, ruaFim: 10, tema_geografico: "China - Estaleiros de Carga" }
    ],
    boss: {
      rua: 11,
      nome: "Dragao Vermelho",
      vida: 2000,
      dano: 110,
      tema_geografico: "China - Estaleiros de Carga"
    }
  },
  {
    ato: 4,
    slug: "SENHORES_DO_DESERTO",
    nome: "Senhores do Deserto",
    regiao: "Mexico - Carteis de Fronteira",
    enemyLevelRange: { min: 16, max: 20 },
    dropLevelRange: { min: 16, max: 20 },
    enemyBaseHealthRange: { min: 800, max: 1200 },
    enemyBaseDamageRange: { min: 75, max: 110 },
    streets: [
      { ruaInicio: 1, ruaFim: 3, tema_geografico: "Mexico - Vilarejos de Fronteira" },
      { ruaInicio: 4, ruaFim: 6, tema_geografico: "Mexico - Pistas de Pouso Clandestinas" },
      { ruaInicio: 7, ruaFim: 10, tema_geografico: "Mexico - Cidades Coloniais" }
    ],
    boss: {
      rua: 11,
      nome: "El Patron",
      vida: 3500,
      dano: 180,
      tema_geografico: "Mexico - Cidades Coloniais"
    }
  },
  {
    ato: 5,
    slug: "A_IRMANDADE_DE_GELO",
    nome: "A Irmandade de Gelo",
    regiao: "Russia - Bratva",
    enemyLevelRange: { min: 21, max: 25 },
    dropLevelRange: { min: 21, max: 25 },
    enemyBaseHealthRange: { min: 1500, max: 2300 },
    enemyBaseDamageRange: { min: 130, max: 200 },
    streets: [
      { ruaInicio: 1, ruaFim: 3, tema_geografico: "Russia - Industrias Sovieticas" },
      { ruaInicio: 4, ruaFim: 6, tema_geografico: "Russia - Estradas da Siberia" },
      { ruaInicio: 7, ruaFim: 10, tema_geografico: "Russia - Palacetes de Moscou" }
    ],
    boss: {
      rua: 11,
      nome: "Vory v Zakone",
      vida: 6000,
      dano: 320,
      tema_geografico: "Russia - Palacetes de Moscou"
    }
  },
  {
    ato: 6,
    slug: "OUTLAWS_DA_ESTRADA",
    nome: "Outlaws da Estrada",
    regiao: "Australia - Biker Gangs",
    enemyLevelRange: { min: 26, max: 30 },
    dropLevelRange: { min: 26, max: 30 },
    enemyBaseHealthRange: { min: 2800, max: 4200 },
    enemyBaseDamageRange: { min: 240, max: 360 },
    streets: [
      { ruaInicio: 1, ruaFim: 3, tema_geografico: "Australia - Oficinas de Desmantele" },
      { ruaInicio: 4, ruaFim: 6, tema_geografico: "Australia - Rodovias Outbacks" },
      { ruaInicio: 7, ruaFim: 10, tema_geografico: "Australia - Pubs de Motoqueiros" }
    ],
    boss: {
      rua: 11,
      nome: "The Road Captain",
      vida: 11000,
      dano: 550,
      tema_geografico: "Australia - Pubs de Motoqueiros"
    }
  },
  {
    ato: 7,
    slug: "CONEXAO_PIRATA",
    nome: "Conexao Pirata",
    regiao: "Somalia/Quenia - Sindicatos Maritimos",
    enemyLevelRange: { min: 31, max: 35 },
    dropLevelRange: { min: 31, max: 35 },
    enemyBaseHealthRange: { min: 5000, max: 7500 },
    enemyBaseDamageRange: { min: 420, max: 620 },
    streets: [
      { ruaInicio: 1, ruaFim: 3, tema_geografico: "Somalia - Mercados de Armas Costeiros" },
      { ruaInicio: 4, ruaFim: 6, tema_geografico: "Somalia - Petroleiros Sequestrados" },
      { ruaInicio: 7, ruaFim: 10, tema_geografico: "Somalia - Ilhas Esconderijo" }
    ],
    boss: {
      rua: 11,
      nome: "O Almirante do Golfo",
      vida: 18000,
      dano: 900,
      tema_geografico: "Somalia - Ilhas Esconderijo"
    }
  },
  {
    ato: 8,
    slug: "SANGUE_E_DIAMANTES",
    nome: "Sangue e Diamantes",
    regiao: "Africa do Sul - Minas de Contrabando",
    enemyLevelRange: { min: 36, max: 40 },
    dropLevelRange: { min: 36, max: 40 },
    enemyBaseHealthRange: { min: 9000, max: 13500 },
    enemyBaseDamageRange: { min: 700, max: 1050 },
    streets: [
      { ruaInicio: 1, ruaFim: 3, tema_geografico: "Africa do Sul - Periferias de Joanesburgo" },
      { ruaInicio: 4, ruaFim: 6, tema_geografico: "Africa do Sul - Mineracao Subterranea" },
      { ruaInicio: 7, ruaFim: 10, tema_geografico: "Africa do Sul - Refinarias Clandestinas" }
    ],
    boss: {
      rua: 11,
      nome: "O Garimpeiro de Sangue",
      vida: 30000,
      dano: 1500,
      tema_geografico: "Africa do Sul - Refinarias Clandestinas"
    }
  },
  {
    ato: 9,
    slug: "IMPERIO_DA_SELVA",
    nome: "Imperio da Selva",
    regiao: "Colombia - Carteis e Guerrilhas / FARCs",
    enemyLevelRange: { min: 41, max: 45 },
    dropLevelRange: { min: 41, max: 45 },
    enemyBaseHealthRange: { min: 16000, max: 24000 },
    enemyBaseDamageRange: { min: 1200, max: 1800 },
    streets: [
      { ruaInicio: 1, ruaFim: 3, tema_geografico: "Colombia - Esconderijos de Medellin" },
      { ruaInicio: 4, ruaFim: 6, tema_geografico: "Colombia - Laboratorios na Selva Fechada" },
      { ruaInicio: 7, ruaFim: 10, tema_geografico: "Colombia - Pistas Clandestinas e Mansoes" }
    ],
    boss: {
      rua: 11,
      nome: "El Patron del Mal",
      vida: 55000,
      dano: 2600,
      tema_geografico: "Colombia - Pistas Clandestinas e Mansoes"
    }
  },
  {
    ato: 10,
    slug: "O_SINDICATO_TROPICAL",
    nome: "O Sindicato Tropical",
    regiao: "Brasil - Mafia dos Morros e Milicias",
    enemyLevelRange: { min: 46, max: 50 },
    dropLevelRange: { min: 46, max: 50 },
    enemyBaseHealthRange: { min: 30000, max: 50000 },
    enemyBaseDamageRange: { min: 2200, max: 3500 },
    streets: [
      { ruaInicio: 1, ruaFim: 3, tema_geografico: "Brasil - Centro Urbano SP" },
      { ruaInicio: 4, ruaFim: 6, tema_geografico: "Brasil - Galpoes da Amazonia" },
      { ruaInicio: 7, ruaFim: 10, tema_geografico: "Brasil - Vielas Fortificadas RJ" }
    ],
    boss: {
      rua: 11,
      nome: "O Barao",
      vida: 150000,
      dano: 6000,
      tema_geografico: "Brasil - Vielas Fortificadas RJ",
      pve_damage_coefficients: {
        FISICO: 0.22,
        PERFURACAO: 1.0,
        FOGO: 1.0,
        ACIDO: 1.0
      },
      isFinalBoss: true
    }
  }
];

export const CONTAINER_DROP_CHANCE = 0.02;
export const GOLD_PER_STREET_LEVEL = 5;
export const STREETS_PER_ACT = 11;
