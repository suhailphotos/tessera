/*
This VEX code applies a bend transformation to geometry based on a specified rotation axis.
How to use:
- When bending along the Y-axis, draw the curve along the X-axis from x = -0.5 to x = 0.5.
- When bending along the X-axis or Z-axis, draw the curve along the Y-axis from y = -0.5 to y = 0.5.

Usage:
1. Set the bend radius (`bend_rad`) and bend angle (`bend_ang`) parameters.
2. Specify the axis of rotation using the `axis` parameter ("x", "y", or "z").
3. Apply the `curvebend` function to the point attribute `@P`.

Example:
float bend_rad = chf('bend_rad');
float bend_ang = chf('bend_ang');
string axis = chs('axis');
vector P = @P;
P = curvebend(P, bend_rad, bend_ang, axis);
@P = P;
*/

// Function to apply bend based on a specified rotation axis
vector apply_bend(vector P; float bend_rad, bend_ang; vector axis_point, rot_axis) {
    P -= axis_point;
    matrix mat = ident();
    float angle;

    // Adjust angle calculation based on the rotation axis
    if (rot_axis == {1.0, 0.0, 0.0}) {
        angle = fit(P.y, -0.5, 0.5, -bend_ang, bend_ang);
    } else if (rot_axis == {0.0, 1.0, 0.0}) {
        angle = fit(P.x, -0.5, 0.5, -bend_ang, bend_ang);
    } else if (rot_axis == set(0.0, 0.0, 1.0)) {
        angle = fit(P.y, -0.5, 0.5, -bend_ang, bend_ang);
    }

    rotate(mat, -angle, rot_axis);
    P *= mat;
    P += axis_point;
    return P;
}

vector curvebend(vector P; float bend_rad, bend_ang; string axis){
    vector rot_axis, axis_point;
    if (axis == "x") {
        rot_axis = {1.0, 0.0, 0.0};
        axis_point = set(0.0, 0.0, -bend_rad);
    } else if (axis == "y") {
        rot_axis = {0.0, 1.0, 0.0};
        axis_point = set(0.0, 0.0, bend_rad);
    } else if (axis == "z") {
        rot_axis = {0.0, 0.0, 1.0};
        axis_point = set(bend_rad, 0.0, 0.0);
    } else {
        rot_axis = {0.0, 1.0, 0.0}; // Default to Y-axis
        axis_point = set(0.0, 0.0, bend_rad);
    }
    
    vector pt1, pt2;
    if (rot_axis == set(1.0, 0.0, 0.0)) {
        pt1 = set(0.0, -0.5, 0.0);
        pt2 = set(0.0, 0.5, 0.0);
    } else if (rot_axis == set(0.0, 1.0, 0.0)) {
        pt1 = set(-0.5, 0.0, 0.0);
        pt2 = set(0.5, 0.0, 0.0);
    } else if (rot_axis == set(0.0, 0.0, 1.0)) {
        pt1 = set(0.0, -0.5, 0.0);
        pt2 = set(0.0, 0.5, 0.0);
    }
    
    vector xfrom_pt1 = apply_bend(pt1, bend_rad, bend_ang, axis_point, rot_axis);
    vector xfrom_pt2 = apply_bend(pt2, bend_rad, bend_ang, axis_point, rot_axis);
    float scaling_fac;
    
    // Adjust scaling factor calculation based on the rotation axis
    if (rot_axis == set(1.0, 0.0, 0.0)) {
        scaling_fac = 1.0 / (xfrom_pt2.y - xfrom_pt1.y);
    } else if (rot_axis == set(0.0, 1.0, 0.0)) {
        scaling_fac = 1.0 / (xfrom_pt2.x - xfrom_pt1.x);
    } else if (rot_axis == set(0.0, 0.0, 1.0)) {
        scaling_fac = 1.0 / (xfrom_pt2.y - xfrom_pt1.y);
    }
    
    P = apply_bend(P, bend_rad, bend_ang, axis_point, rot_axis);
    
    // Adjust the position based on the rotation axis
    if (rot_axis == set(0.0, 1.0, 0.0)) {
        P.z -= xfrom_pt1.z;
    } else if (rot_axis == set(0.0, 0.0, 1.0)) {
        P.x -= xfrom_pt1.x;
    } else if (rot_axis == set(1.0, 0.0, 0.0)) {
        P.z -= xfrom_pt1.z;
    }
    
    P *= scaling_fac;
    return P;
}
