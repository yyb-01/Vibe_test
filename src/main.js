import * as THREE from 'three';
import { PointerLockControls } from 'three/examples/jsm/controls/PointerLockControls.js';

// --- Game State ---
let score = 0;
const scoreElement = document.getElementById('score');
const instructions = document.getElementById('instructions');

// --- Three.js Setup ---
const scene = new THREE.Scene();
scene.background = new THREE.Color(0x87ceeb); // Sky blue background
scene.fog = new THREE.Fog(0x87ceeb, 0, 750);

const camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
camera.position.y = 1.6; // Average eye height

const renderer = new THREE.WebGLRenderer({ antialias: true });
renderer.setSize(window.innerWidth, window.innerHeight);
renderer.setPixelRatio(window.devicePixelRatio);
renderer.shadowMap.enabled = true;
document.body.appendChild(renderer.domElement);

// --- Controls ---
const controls = new PointerLockControls(camera, document.body);

instructions.addEventListener('click', () => {
    controls.lock();
});

controls.addEventListener('lock', () => {
    instructions.style.display = 'none';
});

controls.addEventListener('unlock', () => {
    instructions.style.display = 'flex';
});

scene.add(camera);

// --- Movement Logic ---
let moveForward = false;
let moveBackward = false;
let moveLeft = false;
let moveRight = false;

let prevTime = performance.now();
const velocity = new THREE.Vector3();
const direction = new THREE.Vector3();

const onKeyDown = function (event) {
    switch (event.code) {
        case 'ArrowUp':
        case 'KeyW':
            moveForward = true;
            break;
        case 'ArrowLeft':
        case 'KeyA':
            moveLeft = true;
            break;
        case 'ArrowDown':
        case 'KeyS':
            moveBackward = true;
            break;
        case 'ArrowRight':
        case 'KeyD':
            moveRight = true;
            break;
    }
};

const onKeyUp = function (event) {
    switch (event.code) {
        case 'ArrowUp':
        case 'KeyW':
            moveForward = false;
            break;
        case 'ArrowLeft':
        case 'KeyA':
            moveLeft = false;
            break;
        case 'ArrowDown':
        case 'KeyS':
            moveBackward = false;
            break;
        case 'ArrowRight':
        case 'KeyD':
            moveRight = false;
            break;
    }
};

document.addEventListener('keydown', onKeyDown);
document.addEventListener('keyup', onKeyUp);

// --- Lighting ---
const ambientLight = new THREE.AmbientLight(0xffffff, 0.5);
scene.add(ambientLight);

const dirLight = new THREE.DirectionalLight(0xffffff, 0.8);
dirLight.position.set(100, 200, 50);
dirLight.castShadow = true;
dirLight.shadow.camera.top = 100;
dirLight.shadow.camera.bottom = -100;
dirLight.shadow.camera.left = -100;
dirLight.shadow.camera.right = 100;
scene.add(dirLight);

// --- Environment ---
// Floor
const floorGeometry = new THREE.PlaneGeometry(200, 200);
const floorMaterial = new THREE.MeshLambertMaterial({ color: 0x4a4a4a });
const floor = new THREE.Mesh(floorGeometry, floorMaterial);
floor.rotation.x = -Math.PI / 2;
floor.receiveShadow = true;
scene.add(floor);

// --- Targets ---
const targets = [];
const targetGeometry = new THREE.BoxGeometry(2, 2, 2);
const targetMaterial = new THREE.MeshLambertMaterial({ color: 0xff0000 }); // Red targets

function createTarget() {
    const target = new THREE.Mesh(targetGeometry, targetMaterial);

    // Random position within bounds
    const range = 40;
    target.position.x = (Math.random() - 0.5) * range;
    target.position.y = 1 + Math.random() * 4; // Between height 1 and 5
    target.position.z = (Math.random() - 0.5) * range;

    // Ensure it doesn't spawn too close to player start
    if (target.position.length() < 10) {
        target.position.z -= 10;
    }

    target.castShadow = true;
    target.receiveShadow = true;
    scene.add(target);
    targets.push(target);
}

// Spawn initial targets
for (let i = 0; i < 10; i++) {
    createTarget();
}

// --- Shooting Logic ---
const raycaster = new THREE.Raycaster();

document.addEventListener('mousedown', (event) => {
    if (controls.isLocked) {
        // Raycast from camera center
        raycaster.setFromCamera(new THREE.Vector2(0, 0), camera);

        // Calculate objects intersecting the picking ray
        const intersects = raycaster.intersectObjects(targets);

        if (intersects.length > 0) {
            // Hit detected!
            const hitTarget = intersects[0].object;

            // Remove target from scene and array
            scene.remove(hitTarget);
            targets.splice(targets.indexOf(hitTarget), 1);

            // Update score
            score += 10;
            scoreElement.innerText = score;

            // Spawn a new target to replace it
            createTarget();
        }
    }
});

// --- Window Resize ---
window.addEventListener('resize', () => {
    camera.aspect = window.innerWidth / window.innerHeight;
    camera.updateProjectionMatrix();
    renderer.setSize(window.innerWidth, window.innerHeight);
});

// --- Animation Loop ---
function animate() {
    requestAnimationFrame(animate);

    const time = performance.now();

    if (controls.isLocked === true) {
        const delta = (time - prevTime) / 1000;

        // Apply friction/damping
        velocity.x -= velocity.x * 10.0 * delta;
        velocity.z -= velocity.z * 10.0 * delta;

        // Determine movement direction
        direction.z = Number(moveForward) - Number(moveBackward);
        direction.x = Number(moveRight) - Number(moveLeft);
        direction.normalize(); // Ensure consistent movement speed in all directions

        // Apply acceleration
        const speed = 400.0;
        if (moveForward || moveBackward) velocity.z -= direction.z * speed * delta;
        if (moveLeft || moveRight) velocity.x -= direction.x * speed * delta;

        // Apply movement to controls
        controls.moveRight(-velocity.x * delta);
        controls.moveForward(-velocity.z * delta);
    }

    prevTime = time;

    // Slowly rotate targets for visual flair
    targets.forEach(target => {
        target.rotation.x += 0.01;
        target.rotation.y += 0.01;
    });

    renderer.render(scene, camera);
}

animate();
