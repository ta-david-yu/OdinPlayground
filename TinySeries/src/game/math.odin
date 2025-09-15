package game

import "core:fmt"
import "core:math"
import "core:math/linalg"

Transform::struct {
    Position: [3]f32,
    Rotation: [3]f32,
    Scale: [3]f32
}

TransformMatrix::proc(t: Transform) -> matrix[4, 4]f32 {
    // Unpack
    tx := t.Position[0]; ty := t.Position[1]; tz := t.Position[2]
    rx := t.Rotation[0]; ry := t.Rotation[1]; rz := t.Rotation[2]
    sx := t.Scale[0];    sy := t.Scale[1];    sz := t.Scale[2]

    // Trig (cast to f64 for math.*, then back to f32)
    cx := f32(math.cos(f64(rx))); sxr := f32(math.sin(f64(rx)))
    cy := f32(math.cos(f64(ry))); syr := f32(math.sin(f64(ry)))
    cz := f32(math.cos(f64(rz))); szr := f32(math.sin(f64(rz)))

    // Rotation R = Rz * Ry * Rx (values shown as R[row][col] for clarity)
    R00 :=  cz*cy
    R01 :=  cz*syr*sxr - szr*cx
    R02 :=  cz*syr*cx  + szr*sxr

    R10 :=  szr*cy
    R11 :=  szr*syr*sxr + cz*cx
    R12 :=  szr*syr*cx  - cz*sxr

    R20 := -syr
    R21 :=  cy*sxr
    R22 :=  cy*cx

    M: matrix[4, 4]f32 = {
        R00 * sx, R01 * sy, R02 * sz, tx,
        R10 * sx, R11 * sy, R12 * sz, ty,
        R20 * sx, R21 * sy, R22 * sz, tz,
               0,        0,        0,  1  
    }
    // Since it's column-major, M[3][0] should be tx, M[3][1] is ty

    /*
    // Column-major fill:
    //   column 0 = (R00, R10, R20) * sx
    //   column 1 = (R01, R11, R21) * sy
    //   column 2 = (R02, R12, R22) * sz
    //   column 3 = translation (tx, ty, tz, 1)
    M[0][0] = R00 * sx;  M[0][1] = R10 * sx;  M[0][2] = R20 * sx;  M[0][3] = 0
    M[1][0] = R01 * sy;  M[1][1] = R11 * sy;  M[1][2] = R21 * sy;  M[1][3] = 0
    M[2][0] = R02 * sz;  M[2][1] = R12 * sz;  M[2][2] = R22 * sz;  M[2][3] = 0

    M[3][0] = tx
    M[3][1] = ty
    M[3][2] = tz
    M[3][3] = 1
    */

    return M
}

ViewMatrix::proc(camera: Transform) -> matrix[4, 4]f32 {
    return linalg.inverse(TransformMatrix(camera))
}

PerspectiveProjectionMatrix::proc(fov: f32, aspectRatio: f32, near: f32, far: f32) -> matrix[4, 4]f32 {
    f := 1.0 / math.tan(fov * 0.5)
    return matrix[4, 4]f32 {
        f / aspectRatio, 0, 0, 0,
        0, f, 0, 0,
        0, 0, -(far + near) / (near - far), 2 * far * near / (near - far),
        0, 0, 1, 0
    }
}

ViewportMatrix::proc(x, y, w, h: f32) -> matrix[4, 4]f32 {
    return matrix[4, 4]f32 { 
        w * 0.5, 0, 0, x + w * 0.5,
        0, h * 0.5, 0, y + h * 0.5,
        0, 0, 1, 0,
        0, 0, 0, 1 
    }
}