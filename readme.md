# oke dashboard for above version 1.24

## 1. Downlaod oke dashboard

git clone <https://github.com/nengbai/oke-dashborad.git>

cd oke-dashborad

## 2.Update demain and Genneal cer

bash create_cert.sh oke-admin dashboard example.com kubernetes-dashboard

## 3.Deploy dashboard

kubectl apply -f recommended.yaml

## 4. Check OKE dashboard

kubectl -n kubernetes-dashboard get pod,svc

## 5. Create serviceaccount

kubectl apply -f oke-admin.yaml

## 6. Start proxy and default port is 8001

kubectl proxy

## 7. Browser in firefox or chrome

<http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/>

## 8. Get token from below comamnd

curl 127.0.0.1:8001/api/v1/namespaces/kubernetes-dashboard/serviceaccounts/oke-admin/token -H "Content-Type:application/json" -X POST -d '{}'

example:
"token": "eyJhbGciOiJSUzI1NiIsImtpZCI6ImN0czdrSU1zcVo0c1R3YU9mTzZMMHdjY2JydTdJekt5dXdpQ1Z2d3lRbncifQ.eyJhdWQiOlsiYXBpIl0sImV4cCI6MTY2NjA2ODgyMiwiaWF0IjoxNjY2MDY1MjIyLCJpc3MiOiJodHRwczovL2t1YmVybmV0ZXMuZGVmYXVsdC5zdmMuY2x1c3Rlci5sb2NhbCIsImt1YmVybmV0ZXMuaW8iOnsibmFtZXNwYWNlIjoia3ViZXJuZXRlcy1kYXNoYm9hcmQiLCJzZXJ2aWNlYWNjb3VudCI6eyJuYW1lIjoib2tlLWFkbWluIiwidWlkIjoiMmI0NGMxM2QtNzBkNS00MWI3LTk5MTUtNzQ2MjQxMDFkYzBlIn19LCJuYmYiOjE2NjYwNjUyMjIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprdWJlcm5ldGVzLWRhc2hib2FyZDpva2UtYWRtaW4ifQ.YA8sU6gyW7sTWHBoHO9jtExqrAwIJJ8WRFrNbH4BnSUDK2P0XBAizJafruSfBgksh_ivJrj6TzaTk1UgY6zFfw_fGQ9mB5nWMLVR1yMHTFpAjsUfnEoFU5alv2MBFVJ5mPGBhznoDVi7ZdU29hKr6LLUr2EbOWVHPkeLFtjivGe38S9wpzaL8iGN_bPtV2usJt8ZoYoVtc-jy0stPDm-2idi5aonAjqwKfsyS75WpLdq8Gx25Ge3Rw64diUo5-WgA3aSng7BGvWGR4FWvLKN3VKVVEuyzb5wmIcMb8MAOko1C8lYvma-L0OHA87DmOFGAo1GHQf7O8dtjBjCqVsnWA"

## 9. Update Host in yaml file dashboard-ingress.yaml and Add ingress for oke-dashboard

kubectl apply -f dashboard-ingress.yaml

## 10. Verify oke  dashboard by firefox or chrome

    https://oke-dashboard.example.com
