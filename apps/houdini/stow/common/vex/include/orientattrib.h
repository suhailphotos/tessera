/*
    orientattrib - Function to orient your object so that its up direction 
                   aligns with a given up vector, and its forward (z) direction 
                   aligns with a specified z-axis vector.
                   
    Parameters:
    - vector zaxis: The desired forward direction for the object (the z-axis).
    - vector upaxis: The desired up direction for the object (the up-axis).
    - float angle (optional): The rotation angle in radians to further rotate 
                              the object around a specified axis (default is 0.0).
    - vector rot_axis (optional): The axis around which to apply the additional 
                                  rotation, if an angle is specified (default is {0.0, 1.0, 0.0}).
                                  
    Returns:
    - vector4: The quaternion representing the desired orientation.
    
    Usage:
    This function can be used to reorient an object such that its local up direction 
    is aligned with the provided up vector, and its local forward direction is aligned 
    with the provided z-axis vector. Additionally, an optional rotation can be applied 
    around a specified axis.
    
    Example calls:
    - orientattrib(zaxis, upaxis) 
    - orientattrib(zaxis, upaxis, radians(45)) 
    - orientattrib(zaxis, upaxis, radians(45), {1.0, 0.0, 0.0})
*/

// Main function with all parameters
vector4 orientattrib(vector zaxis, upaxis; float angle; vector rot_axis){
    // Ensure the upaxis is orthogonal to zaxis
    vector xaxis = normalize(cross(upaxis, zaxis));
    upaxis = normalize(cross(zaxis, xaxis));
    
    // Create the transformation matrix from the orthogonal axes
    matrix3 mat = set(xaxis, upaxis, zaxis);
    
    // Convert the transformation matrix to a quaternion
    vector4 orient = quaternion(mat);
    
    // Apply additional rotation if an angle is specified
    if (angle != 0.0){
        vector4 rot = quaternion(angle, rot_axis);
        orient = qmultiply(orient, rot);
    }
    
    return orient;
}

// Overloaded function with default rot_axis
vector4 orientattrib(vector zaxis, upaxis; float angle){
    return orientattrib(zaxis, upaxis, angle, {0.0, 1.0, 0.0});
}

// Overloaded function with default angle and rot_axis
vector4 orientattrib(vector zaxis, upaxis){
    return orientattrib(zaxis, upaxis, 0.0, {0.0, 1.0, 0.0});
}
