// Function to find the nearest cluster for each point
function void nearestclustermapping(int geo; vector positions[]; vector cluster_centers[]; int cluster_assignments[]) {
    int num_clusters = len(cluster_centers);
    
    // Loop over every point
    for (int i = 0; i < len(positions); i++) {
        vector color = positions[i]; // Get the color of the current data point
        int nearest_cluster = 0; // Initialize nearest cluster point index
        vector cluster_color = cluster_centers[nearest_cluster];
        float min_distance = distance(color, cluster_color); // Initialize minimum distance
        
        // Find the nearest cluster center
        for (int c = 1; c < num_clusters; c++) {
            cluster_color = cluster_centers[c];
            float dist = distance(color, cluster_color);
            if (dist < min_distance) {
                min_distance = dist;
                nearest_cluster = c;
            }
        }
        
        // Assign the point to the nearest cluster
        cluster_assignments[i] = nearest_cluster;
    }
}

// K-means Clustering Algorithm for Points
function void kmeanpointsclustering(int geo; int ptnum[]; string vector_attrib; int num_clusters; int max_iterations; int cluster_id[]; vector cluster_val[]) {
    int numpt = len(ptnum);
    int k = num_clusters;
    int max_iters = max_iterations;
    
    // Collect the vector attributes of all points
    vector positions[];
    foreach (int pt; ptnum) {
        vector pos = point(geo, vector_attrib, pt);
        append(positions, pos);
    }
    
    // Initialize first set of random cluster centroids
    vector cluster_centers[];
    for (int i = 0; i < k; i++) {
        int random_ptnum = floor(rand(i) * numpt);
        append(cluster_centers, positions[random_ptnum]);
    }
    
    int cluster_assignments[];
    resize(cluster_assignments, numpt);
    
    // Main K-means loop
    for (int iter = 0; iter < max_iters; iter++) {
        // Call the function to find the nearest cluster for each point and update the cluster assignments array
        nearestclustermapping(geo, positions, cluster_centers, cluster_assignments);
        
        // Initialize cluster sums and counts
        vector cluster_color_sums[];
        int cluster_color_counts[];
        resize(cluster_color_sums, k);
        resize(cluster_color_counts, k);
        
        // Loop over each point to update the sums and counts
        for (int i = 0; i < numpt; i++) {
            int cluster_idx = cluster_assignments[i];
            cluster_color_sums[cluster_idx] += positions[i];
            cluster_color_counts[cluster_idx]++;
        }
        
        // Preserve old cluster_centers with a new array
        vector old_cluster_centers[] = cluster_centers;
        
        // Update cluster_centers array by finding the mean of each cluster's total color
        for (int c = 0; c < k; c++) {
            if (cluster_color_counts[c] > 0) {
                cluster_centers[c] = cluster_color_sums[c] / cluster_color_counts[c];
            }
        }
       
        float total_change = 0;
        for (int c = 0; c < k; c++) {
            total_change += distance(old_cluster_centers[c], cluster_centers[c]);
        }
        if (total_change < 0.001) {
            break;
        }
    }
    
    // Populate the cluster_id and cluster_val arrays
    for (int i = 0; i < numpt; i++) {
        cluster_id[i] = cluster_assignments[i];
        cluster_val[i] = cluster_centers[cluster_assignments[i]];
    }
}

