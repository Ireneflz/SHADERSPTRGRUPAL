using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class LIQUIDSCRIPT : MonoBehaviour
{
    public enum UpdateMode { Normal, UnscaledTime }
    public UpdateMode updateMode;

    [Header("Liquid Settings")]
    [SerializeField] float MaxWobble = 0.03f;
    [SerializeField] float WobbleSpeedMove = 1f;
    [SerializeField] float fillAmount = 0.5f;
    [SerializeField] float Recovery = 1f;
    [SerializeField] float Thickness = 1f;
    [Range(0, 1)] public float CompensateShapeAmount = 1f;

    [Header("Components")]
    [SerializeField] Mesh mesh;
    [SerializeField] Renderer rend;

    private Vector3 lastPos;
    private Quaternion lastRot;
    private Vector3 velocity;
    private Vector3 angularVelocity;

    private float wobbleAmountX;
    private float wobbleAmountZ;
    private float wobbleAmountToAddX;
    private float wobbleAmountToAddZ;
    private float sinewave;
    private float time = 0.5f;

    private Vector3 pos;
    private Vector3 comp;
    private float lowestPointBase;

    // SmoothDamp helpers
    private float wobbleVelocityX;
    private float wobbleVelocityZ;

    void Start()
    {
        GetMeshAndRend();
        lowestPointBase = GetLowestPoint();
        lastPos = transform.position;
        lastRot = transform.rotation;
    }

    private void OnValidate()
    {
        GetMeshAndRend();
        lowestPointBase = GetLowestPoint();
    }

    void GetMeshAndRend()
    {
        if (mesh == null && GetComponent<MeshFilter>())
            mesh = GetComponent<MeshFilter>().sharedMesh;
        if (rend == null)
            rend = GetComponent<Renderer>();
    }

    void Update()
    {
        float deltaTime = (updateMode == UpdateMode.Normal) ? Time.deltaTime : Time.unscaledDeltaTime;
        time += deltaTime;

        if (deltaTime > 0)
        {
            // Calcular velocity correctamente
            velocity = (transform.position - lastPos) / deltaTime;
            angularVelocity = GetAngularVelocity(lastRot, transform.rotation);

            // Agregar efecto de movimiento al wobble
            wobbleAmountToAddX += Mathf.Clamp((velocity.x + velocity.y * 0.2f + angularVelocity.z + angularVelocity.y) * MaxWobble, -MaxWobble, MaxWobble);
            wobbleAmountToAddZ += Mathf.Clamp((velocity.z + velocity.y * 0.2f + angularVelocity.x + angularVelocity.y) * MaxWobble, -MaxWobble, MaxWobble);

            // Suavizar el wobble
            wobbleAmountToAddX = Mathf.SmoothDamp(wobbleAmountToAddX, 0, ref wobbleVelocityX, 1f / Recovery);
            wobbleAmountToAddZ = Mathf.SmoothDamp(wobbleAmountToAddZ, 0, ref wobbleVelocityZ, 1f / Recovery);

            // Sine wave para wobble
            sinewave = Mathf.Sin(2 * Mathf.PI * WobbleSpeedMove * time);
            wobbleAmountX = wobbleAmountToAddX * sinewave;
            wobbleAmountZ = wobbleAmountToAddZ * sinewave;

            // Guardar datos para el próximo frame
            lastPos = transform.position;
            lastRot = transform.rotation;
        }

        // Enviar valores al shader
        rend.sharedMaterial.SetFloat("_WobbleX", wobbleAmountX);
        rend.sharedMaterial.SetFloat("_WobbleZ", wobbleAmountZ);

        // Actualizar posición del líquido
        UpdatePos(deltaTime);
    }


    void UpdatePos(float deltaTime)
    {
        Vector3 worldCenter = transform.TransformPoint(mesh.bounds.center);

        // calcular compensación suavizada
        if (CompensateShapeAmount > 0)
        {
            if (deltaTime != 0)
            {
                comp = Vector3.Lerp(comp, worldCenter - new Vector3(0, lowestPointBase, 0), deltaTime * 10);
            }
            else
            {
                comp = worldCenter - new Vector3(0, lowestPointBase, 0);
            }

            // ajustar la posición del líquido usando fillAmount + compensación
            float adjustedFill = fillAmount + comp.y * CompensateShapeAmount;

            pos = new Vector3(0, adjustedFill, 0);
        }
        else
        {
            pos = new Vector3(0, fillAmount, 0);
        }

        // enviar al shader
        rend.sharedMaterial.SetVector("_FillAmount", pos);
    }


    Vector3 GetAngularVelocity(Quaternion prevRot, Quaternion currRot)
    {
        Quaternion delta = currRot * Quaternion.Inverse(prevRot);

        if (Mathf.Abs(delta.w) > 1023.5f / 1024f)
            return Vector3.zero;

        float gain;
        float angle = Mathf.Acos(Mathf.Clamp(delta.w, -1f, 1f));

        if (delta.w < 0)
            gain = -2f * angle / (Mathf.Sin(angle) * Time.deltaTime);
        else
            gain = 2f * angle / (Mathf.Sin(angle) * Time.deltaTime);

        Vector3 angularVel = new Vector3(delta.x * gain, delta.y * gain, delta.z * gain);
        if (float.IsNaN(angularVel.x) || float.IsNaN(angularVel.y) || float.IsNaN(angularVel.z))
            angularVel = Vector3.zero;

        return angularVel;
    }

    float GetLowestPoint()
    {
        float lowestY = float.MaxValue;
        Vector3[] vertices = mesh.vertices;

        for (int i = 0; i < vertices.Length; i++)
        {
            Vector3 pos = transform.TransformPoint(vertices[i]);
            if (pos.y < lowestY) lowestY = pos.y;
        }

        return lowestY;
    }
}
