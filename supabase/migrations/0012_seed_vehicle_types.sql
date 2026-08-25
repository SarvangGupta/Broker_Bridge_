-- Seed Indian Commercial Vehicle Types into master_vehicle_types
INSERT INTO "master_vehicle_types" ("id", "name", "status")
VALUES
  (gen_random_uuid(), 'Two-Wheeler / Bike (Parcels/Docs)', true),
  (gen_random_uuid(), 'Three-Wheeler / Auto (Small Loads)', true),
  (gen_random_uuid(), 'E-Rickshaw Cargo', true),
  (gen_random_uuid(), 'Tata Ace / Mini Truck', true),
  (gen_random_uuid(), 'Pickup Truck (Bolero Maxi / Dost)', true),
  (gen_random_uuid(), 'LCV – 407 / 709 Class', true),
  (gen_random_uuid(), '14 ft Truck', true),
  (gen_random_uuid(), '17 ft Truck', true),
  (gen_random_uuid(), '19 ft Truck', true),
  (gen_random_uuid(), '22 ft Truck', true),
  (gen_random_uuid(), 'Open Body Truck', true),
  (gen_random_uuid(), 'Closed Body Truck', true),
  (gen_random_uuid(), 'Container Truck (20ft / 32ft / 40ft)', true),
  (gen_random_uuid(), 'Refrigerated Truck (Reefer)', true),
  (gen_random_uuid(), 'Trailer (Flatbed / Low Bed)', true),
  (gen_random_uuid(), 'Multi-Axle Truck (10/12/14 Wheeler)', true),
  (gen_random_uuid(), 'Other Commercial Vehicle', true);
