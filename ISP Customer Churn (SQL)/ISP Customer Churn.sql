-- Create Tabel --
CREATE TABLE customer (
  id TEXT,
  is_tv_subscriber BOOLEAN,
  is_movie_package_subscriber BOOLEAN,
  subscription_age NUMERIC,
  bill_avg NUMERIC,
  reamining_contract NUMERIC,
  service_failure_count INTEGER,
  download_avg NUMERIC,
  upload_avg NUMERIC,
  download_over_limit INTEGER,
  churn BOOLEAN
);

select * from customer;

--========================== Churn Dashboard ==========================--

-- Total and Churned & Stay Customer -- 
SELECT 
  churn,
  COUNT(*) AS total_customers,
  ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM customer), 2) AS percentage
FROM customer
GROUP BY churn
ORDER BY churn Desc;
/*
Tabel ini melihat keseluruhan customer yang churn dan stay di layanan, serta persentasenya
*/


-- Churn Customer by Service Failure --
SELECT 
  service_failure_count,
  SUM(CASE WHEN churn = TRUE THEN 1 ELSE 0 END) AS total_churned_customers
FROM customer
GROUP BY service_failure_count
ORDER BY service_failure_count;
/*
Tabel ini menunjukkan tren churn berdasarkan jumlah kegagalan layanan
*/

SELECT
  ROUND(failure_rate::numeric, 2) AS failure_rate_rounded,
  COUNT(*) AS total_customers
FROM (
  SELECT
    service_failure_count::FLOAT / NULLIF(subscription_age, 0) AS failure_rate
  FROM customer
) sub
WHERE failure_rate IS NOT NULL
GROUP BY failure_rate_rounded
ORDER BY failure_rate_rounded;

/*
Query sebelumnya menunjukkan churn berdasarkan jumlah kegagalan layanan secara total,
bagaimana jika total gangguan banyak tapi ia memang sudah berlangganan sangat lama? bahkan tidak sampai 1 per tahunnya?

maka query ini mempertimbangkan usia berlangganan untuk melihat rata-rata kegagalan layanan per unit waktu berlangganan,
sehingga kita bisa memahami tingkat gangguan relatif terhadap lama pelanggan menggunakan layanan tersebut. 
Dengan begitu, kita mendapatkan gambaran yang lebih adil tentang seberapa sering gangguan benar-benar terjadi selama pelanggan berlanganan,

bukan hanya nilai kumulatifnya saja.
*/


-- Churn Customer by Bill Average
SELECT 
  width_bucket(bill_avg, (SELECT MIN(bill_avg) FROM customer), (SELECT MAX(bill_avg) FROM customer), 9) AS bill_group,
  COUNT(*) AS total_customers,
  SUM(CASE WHEN churn = FALSE THEN 1 ELSE 0 END) AS stay_customers,
  SUM(CASE WHEN churn = TRUE THEN 1 ELSE 0 END) AS churned_customers
FROM customer
GROUP BY bill_group
ORDER BY bill_group;
/*
Tabel ini menunjukkan 9 kelompok rata-rata billing pelanggan dimulai dari paling kecil (1) ke paling besar (9), 
juga seberapa populasi keseluruhan, pelanggan yang menetap, dan pelanggan yang berhenti.
Bertujuan melihat apakah besarnya billing berpengaruh pada customer yang churn?
*/


-- Churn by Subscription Age --
SELECT 
  width_bucket(subscription_age, (SELECT MIN(subscription_age) FROM customer), (SELECT MAX(subscription_age) FROM customer), 10) AS age_group,
  SUM(CASE WHEN churn = TRUE THEN 1 ELSE 0 END) AS churned_customers
FROM customer
GROUP BY age_group
ORDER BY age_group;
/*
Tabel ini menunjukkan 10 kelompok usia berlangganan dan total customer yang berhenti berlangganan tiap kelompok umurnya.
Melihat apakah semakin muda/tua usia berlangganan semakin besar kecenderungannya unuk churn?
*/


-- Top 100 Pelanggan Beresiko Churn --
select id, service_failure_count, subscription_age, reamining_contract
from customer
where service_failure_count >=3 and reamining_contract is null
order by service_failure_count desc, subscription_age desc
LIMIT 100;
/*
Pelanggan tanpa kontrak dan sering mengalami gangguan layanan sangat berisiko churn.
Fokus pada perbaikan layanan dan penawaran kontrak bisa mengurangi potensi churn segmen ini.
Kita juga dapat membaut scoring dari 3 faktor diatas dengan query seperti berikut:
*/


-- Customer Churn Scoring --
WITH churn_risk AS (
  SELECT
    id,
    subscription_age,
    service_failure_count,
    COALESCE(reamining_contract, 0) AS reamining_contract,
    CASE 
      WHEN service_failure_count >= 3 THEN 2
      WHEN service_failure_count >= 1 THEN 1
      ELSE 0
    END +
    CASE 
      WHEN reamining_contract = 0 THEN 2
      ELSE 0
    END +
    CASE 
      WHEN subscription_age < 2 THEN 1
      ELSE 0
    END AS churn_score
  FROM customer
  WHERE churn = false -- hanya pelanggan aktif
)

SELECT *
FROM churn_risk
WHERE churn_score >= 3
ORDER BY churn_score DESC, service_failure_count DESC;

/*
Pelanggan dengan churn_score ≥ 4 adalah segmen berisiko tinggi. Mereka memenuhi kriteria berikut:
- Tidak memiliki kontrak
- Baru bergabung (age rendah)
- Mengalami banyak gangguan
Maka ideal untuk difokuskan pada perbaikan layanan atau intervensi preventif (retensi).
*/
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------
----------------------------------------------------------------------------------



-- Top 1000 Loyal Customer untuk Upsell --
select id, subscription_age, is_tv_subscriber, is_movie_package_subscriber
from customer
where subscription_age >3 
	and is_tv_subscriber = false
	and is_movie_package_subscriber = false
order by subscription_age desc
limit 1000
/*
Segmen ini merupakan pelanggan yang setia dengan layanan dan belum memiliki layanan tambahan.
memungkingkan diberiukan penawaran seperti bundling atau upgrade untuk menaikkan ARPU.
Dapat juga dibentuk perankingkan
*/

	
-- Top 1000 Pelanggan yang sering melebihi kuota / FUP  --
select id, download_over_limit, download_avg, bill_avg 
from customer
where download_over_limit >= 1
order by download_over_limit desc, bill_avg desc
limit 1000;
/*
Segmen ini merupakan pelanggan yang aktif dan banyak mengunakan layanan hingga over limit. Cocok untuk ditawarkan
dalam konteks upselling seperti Speed On Demand, Renew Speed, Upgrade Paket denga FUP lebih besar, dll.
*/

SELECT 
  id,
  download_over_limit,
  download_avg,
  bill_avg,
  subscription_age,
  RANK() OVER (ORDER BY download_over_limit DESC, bill_avg ASC) AS risk_rank
FROM customer
WHERE download_over_limit > 2
  AND bill_avg < 100
  AND churn = false
ORDER BY risk_rank
LIMIT 200;

/*
Pelanggan heavy users dengan download tinggi, melampaui batas (FUP), tapi membayar rendah. Bisa jadi:
- Perlu upgrade paket
- Potensi fair usage abuse
- Bisa dikunci sebagai target untuk naik paket atau monitoring teknis
*/
----------------------------------------------------------------------------------

-- Pelanggan dengan Tagihan Tinggi Tanpa Kontrak --

-- Pelanggan Baru dengan Risiko Churn Tinggi --

-- Pelanggan Sering Gangguan Tanpa Kontrak --

-- Pelanggan Over Limit Data dan Tidak Terikat Kontrak --

-- Pelanggan Tidak Berlangganan TV atau Movie --

-- Pelanggan Setia dengan Potensi Churn Rendah --

-- Pelanggan Aktif Data Tinggi tapi Tidak Punya Paket --

-- Pelanggan Lama dengan Gangguan Berulang --

-- Pelanggan Potensial untuk Diberi Kontrak Jangka Panjang --

-- Pelanggan dengan Nilai Tinggi Tapi Berisiko Churn --


------------------------------------------------------------------------------



