package com.moko.support.d;

import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothGattDescriptor;
import android.content.Context;

import com.elvishew.xlog.XLog;
import com.moko.ble.lib.MokoBleManager;
import com.moko.ble.lib.callback.MokoResponseCallback;
import com.moko.ble.lib.utils.MokoUtils;
import com.moko.support.d.entity.OrderCHAR;
import com.moko.support.d.entity.OrderServices;
import com.moko.support.d.task.PasswordTask;
import com.moko.support.d.task.ParamsTask;

import androidx.annotation.NonNull;

final class MokoBleConfig extends MokoBleManager {

    private MokoResponseCallback mMokoResponseCallback;
    private BluetoothGattCharacteristic paramsCharacteristic;
    private BluetoothGattCharacteristic disconnectCharacteristic;
    private BluetoothGattCharacteristic singleTriggerCharacteristic;
    private BluetoothGattCharacteristic doubleTriggerCharacteristic;
    private BluetoothGattCharacteristic longTriggerCharacteristic;
    private BluetoothGattCharacteristic longConnectionCharacteristic;
    private BluetoothGattCharacteristic accCharacteristic;
    private BluetoothGattCharacteristic passwordCharacteristic;
    private BluetoothGattCharacteristic clickEventCharacteristic;
    private BluetoothGatt gatt;
    private String mPassword = "";
    private final java.util.Queue<byte[]> initQueue = new java.util.LinkedList<>();
    private boolean initRunning = false;

    public void setPassword(String password) {
        this.mPassword = password != null ? password : "";
    }

    public MokoBleConfig(@NonNull Context context, MokoResponseCallback callback) {
        super(context);
        mMokoResponseCallback = callback;
    }

    public BluetoothGattCharacteristic getPasswordCharacteristic() {
        return passwordCharacteristic;
    }

    public BluetoothGattCharacteristic getParamsCharacteristic() {
        return paramsCharacteristic;
    }

    public void closeDirectly() {
        if (gatt != null) {
            try {
                gatt.disconnect();
                gatt.close();
                android.util.Log.d("MkButtonSDK", "closeDirectly: stale GATT closed for " + gatt.getDevice().getAddress());
            } catch (Exception e) {
                android.util.Log.e("MkButtonSDK", "closeDirectly error: " + e.getMessage());
            }
            gatt = null;
        }
    }

    public void writeDescriptorDirectly(BluetoothGattCharacteristic characteristic, byte[] value) {
        if (gatt != null && characteristic != null) {
            BluetoothGattDescriptor descriptor = characteristic.getDescriptor(
                java.util.UUID.fromString("00002902-0000-1000-8000-00805f9b34fb"));
            if (descriptor != null) {
                descriptor.setValue(value);
                gatt.writeDescriptor(descriptor);
                android.util.Log.d("MkButtonSDK", "Descriptor written for " + characteristic.getUuid());
            }
        }
    }

    public void writeDirectly(BluetoothGattCharacteristic characteristic, byte[] data) {
        if (gatt != null && characteristic != null) {
            characteristic.setValue(data);
            characteristic.setWriteType(BluetoothGattCharacteristic.WRITE_TYPE_NO_RESPONSE);
            gatt.writeCharacteristic(characteristic);
            android.util.Log.d("MkButtonSDK", "Direct write: " + MokoUtils.bytesToHexString(data));
        } else {
            android.util.Log.d("MkButtonSDK", "Direct write FAILED: gatt or characteristic is null");
        }
    }

    public void queueInitCommands() {
        android.os.Handler h = new android.os.Handler(android.os.Looper.getMainLooper());
        // firmware ya se envió como primer comando
        h.postDelayed(() -> writeDirectly(paramsCharacteristic, 
            new byte[]{(byte)0xEA,(byte)0x00,(byte)0x2C,(byte)0x00}), 600);  // 600ms como Wireshark
        h.postDelayed(() -> writeDirectly(paramsCharacteristic, 
            new byte[]{(byte)0xEA,(byte)0x00,(byte)0x2C,(byte)0x00}), 1200); // segunda vez
        h.postDelayed(() -> {
            if (gatt != null && clickEventCharacteristic != null) {
                gatt.setCharacteristicNotification(clickEventCharacteristic, true);
                writeDescriptorDirectly(clickEventCharacteristic,
                    BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
            }
        }, 1800);
    }

    public void sendNextInit() {
        byte[] next = initQueue.poll();
        if (next != null) {
            initRunning = true;
            writeDirectly(paramsCharacteristic, next);
        } else {
            initRunning = false;
            android.util.Log.d("MkButtonSDK", "Init complete, writing descriptor");
            if (clickEventCharacteristic != null && gatt != null) {
                gatt.setCharacteristicNotification(clickEventCharacteristic, true);
                writeDescriptorDirectly(clickEventCharacteristic,
                    BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
            }
        }
    }

    @Override
    public boolean checkServiceCharacteristicSupported(BluetoothGatt gatt) {
        final BluetoothGattService service = gatt.getService(OrderServices.SERVICE_CUSTOM.getUuid());
        if (service != null) {
            this.gatt = gatt;
            paramsCharacteristic = service.getCharacteristic(OrderCHAR.CHAR_PARAMS.getUuid());
            disconnectCharacteristic = service.getCharacteristic(OrderCHAR.CHAR_DISCONNECT.getUuid());
            singleTriggerCharacteristic = service.getCharacteristic(OrderCHAR.CHAR_SINGLE_TRIGGER.getUuid());
            doubleTriggerCharacteristic = service.getCharacteristic(OrderCHAR.CHAR_DOUBLE_TRIGGER.getUuid());
            longTriggerCharacteristic = service.getCharacteristic(OrderCHAR.CHAR_LONG_TRIGGER.getUuid());
            longConnectionCharacteristic = service.getCharacteristic(OrderCHAR.CHAR_LONG_CONNECTION.getUuid());
            accCharacteristic = service.getCharacteristic(OrderCHAR.CHAR_ACC.getUuid());
            passwordCharacteristic = service.getCharacteristic(OrderCHAR.CHAR_PASSWORD.getUuid());
            clickEventCharacteristic = service.getCharacteristic(OrderCHAR.CHAR_CLICK_EVENT.getUuid());
            return passwordCharacteristic != null
                    && disconnectCharacteristic != null
                    && paramsCharacteristic != null;
        }
        return false;
    }

    @Override
    public void init() {
        requestMtu(247).with(((device, mtu) -> {
        })).then((device -> {
            enablePasswordNotify();
            enableParamsNotify();
        })).enqueue();
    }

    @Override
    public void write(BluetoothGattCharacteristic characteristic, byte[] value) {
    }

    @Override
    public void read(BluetoothGattCharacteristic characteristic, byte[] value) {
        mMokoResponseCallback.onCharacteristicRead(characteristic, value);
    }

    @Override
    public void onDeviceConnecting(@NonNull BluetoothDevice device) {

    }

    @Override
    public void onDeviceConnected(@NonNull BluetoothDevice device) {

    }

    @Override
    public void onDeviceDisconnecting(@NonNull BluetoothDevice device) {
        android.util.Log.w("MkButtonSDK", "!!! onDeviceDisconnecting called !!!");
        android.util.Log.w("MkButtonSDK", "Stack trace:", new Exception());
        XLog.w("onDeviceDisconnecting");
    }

    @Override
    public void onDeviceDisconnected(@NonNull BluetoothDevice device, int reason) {
        android.util.Log.w("MkButtonSDK", "!!! onDeviceDisconnected called !!! Reason: " + reason);
        android.util.Log.w("MkButtonSDK", "Reason codes: 0=SUCCESS, 8=TIMEOUT, 19=REMOTE_DISCONNECT, 22=LOCAL_DISCONNECT, 133=GATT_ERROR");
        android.util.Log.w("MkButtonSDK", "Stack trace:", new Exception());
        stopKeepAlive();
        mMokoResponseCallback.onDeviceDisconnected(device, reason);
    }

    @Override
    public void onDeviceReady(@NonNull BluetoothDevice device) {
        android.util.Log.d("MkButtonSDK", "onDeviceReady called");
    }
    
    @Override
    public void onDeviceFailedToConnect(@NonNull BluetoothDevice device, int reason) {
        android.util.Log.e("MkButtonSDK", "!!! onDeviceFailedToConnect !!! Reason: " + reason);
    }


    public void enableParamsNotify() {
        setNotificationCallback(paramsCharacteristic).with((device, data) -> {
            final byte[] value = data.getValue();
            XLog.e("onDataReceived");
            XLog.e("device to app : " + MokoUtils.bytesToHexString(value));
            mMokoResponseCallback.onCharacteristicChanged(paramsCharacteristic, value);
        });
        enableNotifications(paramsCharacteristic).done(device -> mMokoResponseCallback.onServicesDiscovered(gatt)).enqueue();
    }

    public void disableParamsNotify() {
        disableNotifications(paramsCharacteristic).enqueue();
    }

    public void enableDisconnectNotify() {
        setNotificationCallback(disconnectCharacteristic).with((device, data) -> {
            final byte[] value = data.getValue();
            android.util.Log.w("MkButtonSDK", "!!! DISCONNECT CHARACTERISTIC RECEIVED: " + MokoUtils.bytesToHexString(value));
            android.util.Log.w("MkButtonSDK", "!!! This may trigger device disconnection!");
            XLog.e("onDataReceived");
            XLog.e("device to app : " + MokoUtils.bytesToHexString(value));
            mMokoResponseCallback.onCharacteristicChanged(disconnectCharacteristic, value);
        });
        enableNotifications(disconnectCharacteristic).enqueue();
    }

    public void disableDisconnectNotify() {
        disableNotifications(disconnectCharacteristic).enqueue();
    }

    public void enablePasswordNotify() {
        setNotificationCallback(passwordCharacteristic).with((device, data) -> {
            final byte[] value = data.getValue();
            android.util.Log.d("MkButtonSDK", "PASSWORD notify received: " + MokoUtils.bytesToHexString(value));

            if ((value[0] & 0xFF) == 0xEB && (value[1] & 0xFF) == 0x01 && (value[2] & 0xFF) == 0x55) {
                if (value.length >= 5 && (value[4] & 0xFF) == 0x00) {
                    android.util.Log.e("MkButtonSDK", "Password REJECTED by device - disconnecting");
                    disconnect().enqueue();
                    mMokoResponseCallback.onCharacteristicChanged(passwordCharacteristic, value);
                    return;
                }
                android.util.Log.d("MkButtonSDK", "Password accepted! Starting init sequence...");
                
                // Secuencia de inicialización simplificada (como app oficial)
                android.os.Handler handler = new android.os.Handler(android.os.Looper.getMainLooper());
                
                // 1. Comando 0x57 - Confirmar autenticación (inmediato)
                writeDirectly(paramsCharacteristic, new byte[]{(byte)0xEA,(byte)0x00,(byte)0x57,(byte)0x00});
                android.util.Log.d("MkButtonSDK", "Sent: EA 00 57 00 (auth confirm)");
                
                // 2. Comando 0x2C - Leer configuración/modelo (300ms después) - SOLO UNA VEZ
                handler.postDelayed(() -> {
                    writeDirectly(paramsCharacteristic, new byte[]{(byte)0xEA,(byte)0x00,(byte)0x2C,(byte)0x00});
                    android.util.Log.d("MkButtonSDK", "Sent: EA 00 2C 00 (read config)");
                }, 300);
                
                // 3. Habilitar notificaciones de click event (600ms después)
                handler.postDelayed(() -> {
                    android.util.Log.d("MkButtonSDK", "Enabling click event notifications...");
                    enableClickEventNotify();
                    // NO deshabilitamos CHAR_PARAMS porque el SDK base podría tener comandos pendientes
                }, 600);
            }
            mMokoResponseCallback.onCharacteristicChanged(passwordCharacteristic, value);
        });
        enableNotifications(passwordCharacteristic).enqueue();
    }

    public void disablePasswordNotify() {
        disableNotifications(passwordCharacteristic).enqueue();
    }

    public void enableSingleTriggerNotify() {
        setNotificationCallback(singleTriggerCharacteristic).with((device, data) -> {
            final byte[] value = data.getValue();
            XLog.e("onDataReceived");
            XLog.e("device to app : " + MokoUtils.bytesToHexString(value));
            mMokoResponseCallback.onCharacteristicChanged(singleTriggerCharacteristic, value);
        });
        enableNotifications(singleTriggerCharacteristic).enqueue();
    }

    public void disableSingleTriggerNotify() {
        disableNotifications(singleTriggerCharacteristic).enqueue();
    }

    public void enableDoubleTriggerNotify() {
        setNotificationCallback(doubleTriggerCharacteristic).with((device, data) -> {
            final byte[] value = data.getValue();
            XLog.e("onDataReceived");
            XLog.e("device to app : " + MokoUtils.bytesToHexString(value));
            mMokoResponseCallback.onCharacteristicChanged(doubleTriggerCharacteristic, value);
        });
        enableNotifications(doubleTriggerCharacteristic).enqueue();
    }

    public void disableDoubleTriggerNotify() {
        disableNotifications(doubleTriggerCharacteristic).enqueue();
    }

    public void enableLongTriggerNotify() {
        setNotificationCallback(longTriggerCharacteristic).with((device, data) -> {
            final byte[] value = data.getValue();
            XLog.e("onDataReceived");
            XLog.e("device to app : " + MokoUtils.bytesToHexString(value));
            mMokoResponseCallback.onCharacteristicChanged(longTriggerCharacteristic, value);
        });
        enableNotifications(longTriggerCharacteristic).enqueue();
    }

    public void disableLongTriggerNotify() {
        disableNotifications(longTriggerCharacteristic).enqueue();
    }

    public void enableAccNotify() {
        setNotificationCallback(accCharacteristic).with((device, data) -> {
            final byte[] value = data.getValue();
            XLog.e("onDataReceived");
            XLog.e("device to app : " + MokoUtils.bytesToHexString(value));
            mMokoResponseCallback.onCharacteristicChanged(accCharacteristic, value);
        });
        enableNotifications(accCharacteristic).enqueue();
    }

    public void disableAccNotify() {
        disableNotifications(accCharacteristic).enqueue();
    }

    public void enableClickEventNotify() {
        setNotificationCallback(clickEventCharacteristic).with((device, data) -> {
            final byte[] value = data.getValue();
            android.util.Log.d("MkButtonSDK", "Click event received: " + MokoUtils.bytesToHexString(value));
            XLog.e("onDataReceived");
            XLog.e("device to app : " + MokoUtils.bytesToHexString(value));
            mMokoResponseCallback.onCharacteristicChanged(clickEventCharacteristic, value);
        });
        enableNotifications(clickEventCharacteristic).done(device -> {
            android.util.Log.d("MkButtonSDK", "Click event notifications enabled - initialization complete");
            android.util.Log.d("MkButtonSDK", "Device ready. Connection will stay active with notifications.");
        }).enqueue();
    }

    public void disableClickEventNotify() {
        disableNotifications(clickEventCharacteristic).enqueue();
    }

    public void enableLongConnectionNotify() {
        setNotificationCallback(longConnectionCharacteristic).with((device, data) -> {
            final byte[] value = data.getValue();
            XLog.e("onDataReceived");
            XLog.e("device to app : " + MokoUtils.bytesToHexString(value));
            mMokoResponseCallback.onCharacteristicChanged(longConnectionCharacteristic, value);
        });
        enableNotifications(longConnectionCharacteristic).enqueue();
    }

    public void disableLongConnectionNotify() {
        disableNotifications(longConnectionCharacteristic).enqueue();
    }

    public void startKeepAlive() {
        android.util.Log.d("MkButtonSDK", "startKeepAlive: delegated to DMokoSupport.sendOrder(setConnectInterval)");
    }

    private void stopKeepAlive() {
        // no-op: connection interval is set once, no periodic task to cancel
    }
}