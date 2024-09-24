/**
 * Copyright 2020 Google LLC
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
locals {
  network_name    = var.create_network ? google_compute_network.gh-network[0].name : var.network_name
  subnet_name     = var.create_network ? google_compute_subnetwork.gh-subnetwork[0].name : var.subnet_name
  service_account = var.service_account == "" ? "create" : var.service_account
}

/*****************************************
  Optional Network
 *****************************************/
resource "google_compute_network" "gh-network" {
  count                   = var.create_network ? 1 : 0
  name                    = var.network_name
  project                 = var.project_id
  auto_create_subnetworks = false
}
resource "google_compute_subnetwork" "gh-subnetwork" {
  count         = var.create_network ? 1 : 0
  project       = var.project_id
  name          = var.subnet_name
  ip_cidr_range = var.subnet_ip
  region        = var.region
  network       = google_compute_network.gh-network[0].name

  secondary_ip_range {
    range_name    = var.ip_range_pods_name
    ip_cidr_range = var.ip_range_pods_cidr
  }

  secondary_ip_range {
    range_name    = var.ip_range_services_name
    ip_cidr_range = var.ip_range_services_cider
  }
}
/*****************************************
  Runner GKE
 *****************************************/
module "runner-cluster" {
  source                   = "terraform-google-modules/kubernetes-engine/google//modules/beta-public-cluster/"
  version                  = "~> 32.0"
  project_id               = var.project_id
  name                     = "gh-runner-${var.cluster_suffix}"
  regional                 = false
  region                   = var.region
  zones                    = var.zones
  network                  = local.network_name
  network_project_id       = var.subnetwork_project != "" ? var.subnetwork_project : var.project_id
  subnetwork               = local.subnet_name
  ip_range_pods            = var.ip_range_pods_name
  ip_range_services        = var.ip_range_services_name
  logging_service          = "logging.googleapis.com/kubernetes"
  monitoring_service       = "monitoring.googleapis.com/kubernetes"
  remove_default_node_pool = true
  service_account          = local.service_account
  gce_pd_csi_driver        = true
  deletion_protection      = false
  node_pools = [
    {
      name                 = "runner-pool"
      min_count            = var.min_node_count
      max_count            = var.max_node_count
      auto_upgrade         = true
      machine_type         = var.machine_type
      enable_private_nodes = var.enable_private_nodes
    }
  ]
}

data "google_client_config" "default" {
}

